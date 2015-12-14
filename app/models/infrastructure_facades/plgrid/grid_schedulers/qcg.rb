 require_relative '../pl_grid_scheduler_base'

module QcgScheduler

  class PlGridScheduler < PlGridSchedulerBase
    JOBID_RE = /.*jobId\s+=\s+(.+)$/
    STATE_RE = /.*Status:\s+(\w+).*/
    STATUS_DESCRIPTION_RE = /.*StatusDescription:\s+(.*)\n/
    STATUS_DESC_RE = /.*StatusDesc:\s+(.*)\n/

    DEFAULT_PROXY_DURATION_H = 12

    def self.long_name
      'PL-Grid QosCosGrid'
    end

    def self.short_name
      'qcg'
    end

    def long_name
      self.class.long_name
    end

    def short_name
      self.class.short_name
    end

    def onsite_monitorable?
      true
    end

    def prepare_job_files(sm_uuid, params)
      execution_dir = if params.include?(:dest_dir)
        params[:dest_dir]
      else
        LocalAbsoluteDir::tmp
      end

      params = params[:sm_record] if params.include?(:sm_record)

      IO.write("#{execution_dir}/#{job_script_file(sm_uuid)}", prepare_job_executable)
      IO.write("#{execution_dir}/#{job_qcg_file(sm_uuid)}", prepare_job_descriptor(sm_uuid, params))
    end

    # Script uses working dir (where job is submitted) relative paths
    def prepare_job_descriptor(uuid, params)
      log_path = ScalarmFileName::sim_log(uuid)
      <<-eos
#QCG executable=#{job_script_file(uuid)}
#QCG argument=#{uuid}
#QCG output=#{log_path}.out
#QCG error=#{log_path}.err
#QCG stage-in-file=#{job_script_file(uuid)}
#QCG stage-in-file=#{ScalarmFileName::tmp_sim_zip(uuid)}
#QCG host=#{params['plgrid_host'] or 'zeus.cyfronet.pl'}
#QCG queue=#{params['queue_name'] or PlGridJob.queue_for_minutes(params['time_limit'].to_i)}
#QCG walltime=#{self.class.minutes_to_walltime(params['time_limit'].to_i)}
#{params['nodes'].blank? ? '' : "#QCG nodes=#{params['nodes']}:#{params['ppn']}" }
#{params['grant_id'].blank? ? '' : "#QCG grant=#{params['grant_id']}" }
      eos
    end

    def self.minutes_to_walltime(minutes)
      hh, mm = minutes.divmod(60)
      dd, hh = hh.divmod(24)
      "P#{dd}DT#{hh}H#{mm}M"
    end

    def tmp_job_files_list(sm_uuid)
      [
          job_script_file(sm_uuid),
          job_qcg_file(sm_uuid)
      ].collect {|name| File.join(LocalAbsoluteDir::tmp, name)}
    end

    def submit_job(ssh, job)
      cmd = Command::cd_to_simulation_managers(submit_job_cmd(job))
      submit_job_output = ssh.exec!(cmd)
      logger.debug("QCG cmd: #{cmd}, output lines:\n#{submit_job_output}")

      job_id = PlGridScheduler.parse_job_id(submit_job_output)
      job_id ? job_id : raise(JobSubmissionFailed.new(submit_job_output))
    end

    def submit_job_cmd(sm_record)
      BashCommand.new.
          append("chmod a+x #{job_script_file(sm_record.sm_uuid)}").
          append(PlGridScheduler.qcg_command("qcg-sub #{job_qcg_file(sm_record.sm_uuid)}"))
    end

    def self.parse_job_id(submit_job_output)
      jobid_match = submit_job_output.match(JOBID_RE)
      jobid_match ? jobid_match[1] : nil
    end

    # QCG Job states
    # UNSUBMITTED – task processing suspended because of queue dependencies
    # UNCOMMITED - task is waiting for processing confirmation
    # QUEUED – task is waiting in queue for processing
    # PREPROCESSING – system is preparing environment for task
    # PENDING – application waits for execution in queuing system in terms of job,
    # RUNNING – user's appliaction is running in terms of job,
    # STOPPED – application execution has been completed, but queuing system does not copied results and cleaned environment
    # POSTPROCESSING – queuing system ends job: copies result files, cleans environment, etc.
    # FINISHED – job has been completed
    # FAILED – error processing job
    # CANCELED – job has been cancelled by user

    STATES_MAPPING = {
        'UNSUBMITTED' => :initializing,
        'UNCOMMITED' => :initializing,
        'QUEUED' => :initializing,
        'PREPROCESSING' => :initializing,
        'PENDING' => :initializing,
        'RUNNING' => :running,
        'STOPPED' => :running,
        'POSTPROCESSING' => :deactivated,
        'FINISHED' => :deactivated,
        'FAILED' => :deactivated,
        'CANCELED' => :deactivated,
        'UNKNOWN' => :error
    }

    def status(ssh, job)
      STATES_MAPPING[qcg_state(ssh, job.job_identifier)] or :error
    end

    def qcg_state(ssh, job_id)
      QcgScheduler::PlGridScheduler.parse_qcg_state(get_job_info(ssh,job_id))
    end

    def qcg_status_desc(ssh, job_id)
      QcgScheduler::PlGridScheduler.parse_qcg_status_desc(get_job_info(ssh,job_id))
    end

    def self.parse_qcg_state(state_output)
      state_match = state_output.match(STATE_RE)
      if state_match
        state_match[1]
      else
        'UNKNOWN'
      end
    end

    def self.parse_qcg_status_desc(output)
      state_match = output.match(STATUS_DESC_RE)
      if state_match
        state_match[1]
      else
        nil
      end
    end

    def get_job_info(ssh, job_id)
      ssh.exec!(get_job_info_cmd(job_id).to_s)
    end

    def get_job_info_cmd(job_id)
      BashCommand.new.append(PlGridScheduler.qcg_command("qcg-info #{job_id}"))
    end

    def cancel(ssh, job)
      output = ssh.exec!(cancel_sm_cmd(job).to_s)
      logger.debug("QCG cancel output:\n#{output}")
      output
    end

    def cancel_sm_cmd(sm_record)
      BashCommand.new.append(PlGridScheduler.qcg_command("qcg-cancel #{sm_record.job_identifier} || true"))
    end

    def get_log(ssh, job)
      ssh.exec!(get_log_cmd(job).to_s)
    end

    def get_log_cmd(sm_record)
      absolute_log_path = sm_record.absolute_log_path
      stdout_path = "#{absolute_log_path}.out"
      stderr_path = "#{absolute_log_path}.err"

      BashCommand.new.
          echo("--- QCG info ---").
          append(sm_record.job_identifier.blank? ? '' : get_job_info_cmd(sm_record.job_identifier)).
          echo("--- STDOUT ---").
          tail(stdout_path, 40).
          echo("--- STDERR ---").
          tail(stderr_path, 40).
          append("rm -f #{stderr_path} #{stderr_path}")
    end

    def clean_after_sm_cmd(sm_record)
      BashCommand.new.append(super).rm(File.join(RemoteDir::scalarm_root, job_qcg_file(sm_record.sm_uuid)), true)
    end

    def self.available_hosts
      [
        'zeus.cyfronet.pl',
        'nova.wcss.wroc.pl',
        'galera.task.gda.pl',
        'reef.man.poznan.pl',
        'inula.man.poznan.pl',
        'hydra.icm.edu.pl',
        'moss.man.poznan.pl'
      ]
    end

    # Wraps QCG command with additional enviroment variables
    # Proxy duration is in hours and it must be shorter than current proxy cert duration
    def self.qcg_command(command, proxy_duration_h=DEFAULT_PROXY_DURATION_H)
      "QCG_ENV_PROXY_DURATION_MIN=#{proxy_duration_h} #{command}"
    end

    def job_qcg_file(sm_uuid)
      "scalarm_job_#{sm_uuid}.qcg"
    end

    ##
    # Returns list of hashes representing distinct configurations of infrastructure
    # Subinfrastructures are distinguished by:
    #  * PLGrid hosts
    #  * grant ids
    def get_infrastructure_configurations(user_id)
      hosts = self.class.available_hosts
      grant_ids = PlGridFacade.retrieve_grants(GridCredentials.find_by_user_id(user_id))

      hosts.flat_map do |host|
        grant_ids.flat_map do |grant_id|
          {name: short_name.to_sym, params: {plgrid_host: host, grant_id: grant_id}}
        end
      end
    end

  end

end