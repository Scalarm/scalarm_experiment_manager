require_relative '../pl_grid_scheduler_base'

module QsubScheduler

  class PlGridScheduler < PlGridSchedulerBase
    def self.long_name
      'PL-Grid PBS'
    end

    def self.short_name
      'qsub'
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
      IO.write("#{execution_dir}/#{job_pbs_file(sm_uuid)}", prepare_job_descriptor(sm_uuid, params))
    end

    def tmp_job_files_list(sm_uuid)
      [
          job_script_file(sm_uuid),
          job_pbs_file(sm_uuid)
      ].collect {|name| File.join(LocalAbsoluteDir::tmp, name)}
    end

    def submit_job(ssh, sm_record)
      cmd = chain(Command::cd_to_simulation_managers(submit_job_cmd(sm_record)))
      submit_job_output = ssh.exec!(cmd)
      logger.debug("PBS cmd: #{cmd}, output lines:\n#{submit_job_output}")

      m = submit_job_output.match(/\d+.batch.grid.cyf-kr.edu.pl/)

      m ? m[0] : raise(JobSubmissionFailed.new(submit_job_output))
    end

    # Assumption: working dir contains job files
    def submit_job_cmd(sm_record)
      sm_uuid = sm_record.sm_uuid

      chain(
          "chmod a+x #{job_script_file(sm_uuid)}",
          "qsub #{job_pbs_file(sm_uuid)}"
      )
    end

    def prepare_job_descriptor(uuid, params)
      log_path = ScalarmFileName::sim_log(uuid)
      <<-eos
#!/bin/bash
#PBS -q #{PlGridJob.queue_for_minutes(params['time_limit'].to_i)}
#PBS -j oe
#PBS -o #{log_path}
#PBS -l walltime=#{params['time_limit'].to_i.minutes.to_i}
#{params['nodes'].blank? ? '' : "#PBS -l nodes=#{params['nodes']}:ppn=#{params['ppn'] || 1}" }
#{params['grant_id'].blank? ? '' : "#PBS -A #{params['grant_id']}" }

cd $PBS_O_WORKDIR
./#{job_script_file(uuid)} #{uuid} # SiM unpacking and execution script
      eos
    end

    def pbs_state(ssh, job)
      state_output = ssh.exec!("qstat #{job.job_id}")
      state_output.split("\n").each do |line|
        if line.start_with?(job.job_id.split('.').first)
          info = line.split(' ')
          return info[4]

        elsif line.start_with?('qstat: Unknown Job Id')
          return 'U'
        end
      end
      # unknown
      'U'
    end

    # States from man qstat:
    # C -  Job is completed after having run/
    # E -  Job is exiting after having run.
    # H -  Job is held.
    # Q -  job is queued, eligible to run or routed.
    # R -  job is running.
    # T -  job is being moved to new location.
    # W -  job is waiting for its execution time
    # (-a option) to be reached.
    # S -  (Unicos only) job is suspend.

    STATES_MAPPING = {
        'C'=>:deactivated,
        'E'=>:deactivated,
        'H'=>:running,
        'Q'=>:initializing,
        'R'=>:running,
        'T'=>:running,
        'W'=>:initializing,
        'S'=>:error,
        'U'=>:deactivated # probably it's not in queue
    }

    def status(ssh, job)
      STATES_MAPPING[pbs_state(ssh, job)] or :error
    end

    def cancel(ssh, job)
      cmd = cancel_sm_cmd(job)
      output = ssh.exec!(cmd)
      logger.debug("PBS cmd: #{cmd}, output lines:\n#{output}")
    end

    def get_log(ssh, job)
      ssh.exec! get_log_cmd(job)
    end

    def get_log_cmd(sm_record)
      log_path = sm_record.absolute_log_path
      if log_path.blank?
        'echo no log_path specified'
      else
        "tail -80 #{log_path}; rm -f #{log_path}"
      end
    end

    def cancel_sm_cmd(sm_record)
      if sm_record.job_id.blank?
        'echo no job_id specified'
      else
        "qdel #{sm_record.job_id}"
      end
    end

    def clean_after_sm_cmd(sm_record)
      chain(super, rm(File.join(RemoteDir::scalarm_root, job_pbs_file(sm_record.sm_uuid))))
    end

    def job_pbs_file(sm_uuid)
      "scalarm_job_#{sm_uuid}.pbs"
    end


  end

end