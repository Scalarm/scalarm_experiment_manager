require_relative '../pl_grid_scheduler_base'

require 'infrastructure_facades/shell_commands'
include ShellCommands

module GliteScheduler

  class PlGridScheduler < PlGridSchedulerBase
    def initialize(logger)
      super(logger)
      @last_ssh = nil
    end

    def self.long_name
      'PL-Grid gLite'
    end

    def self.short_name
      'glite'
    end

    def long_name
      self.class.long_name
    end

    def short_name
      self.class.short_name
    end

    def prepare_job_files(sm_uuid, params)
      [
          [job_script_file(sm_uuid), prepare_job_executable],
          [job_jdl_file(sm_uuid), prepare_job_descriptor(sm_uuid, params)]
      ].each do |file, content|
        IO.write(File.join(LocalAbsoluteDir::tmp, file), content)
      end
    end

    def tmp_job_files_list(sm_uuid)
      [
          job_script_file(sm_uuid),
          job_jdl_file(sm_uuid)
      ].collect {|name| File.join(LocalAbsoluteDir::tmp, name)}
    end

    def submit_job(ssh, job)
      ssh.exec!(Command::cd_to_simulation_managers("chmod a+x #{job_script_file(job.sm_uuid)}"))
      #  schedule the job with glite wms
      submit_job_output =
          PlGridScheduler.execute_glite_command(
              Command::cd_to_simulation_managers("glite-wms-job-submit -a #{job_jdl_file(job.sm_uuid)}"),
              ssh)
      logger.debug("Glite submission output lines: #{submit_job_output}")

      job_id = GliteScheduler::PlGridScheduler.parse_job_id(submit_job_output)
      job_id ? job_id : raise(JobSubmissionFailed.new(submit_job_output))
    end

    def self.parse_job_id(submit_job_output)
      match = submit_job_output.match /Your job identifier is:\s+(\S+)/
      match ? match[1] : nil
    end

    def get_job_info(ssh, job_id)
      PlGridScheduler.execute_glite_command(
          chain(Command::cd_to_simulation_managers("glite-wms-job-status #{job_id}")),
          ssh
      )
    end

    def glite_state(ssh, job_id)
      GliteScheduler::PlGridScheduler.parse_job_status(get_job_info(ssh, job_id))
    end

    def self.parse_job_status(state_output)
      match = state_output.match /Current Status:\s+(.*)$/
      match ? match[1] : nil
    end

    # --- gLite states:
    # Submitted -	The job has been submitted by the user but not yet processed by the RB
    # Waiting	- The job has been accepted by the RB but not yet matched to a CE
    # Ready	- The job has been assigned to a CE but not yet transferred to it
    # Scheduled	- The job is waiting in the local batch system queue on the CE
    # Running	- The job is running on a WN
    # Done(Success) - The job has finished successfully
    # Cleared - The Output Sandbox has been retrieved by the user
    # Aborted
    # Done(Exit Code !=0)

    STATES_MAPPING = {
        'Submitted' => :initializing,
        'Waiting' => :initializing,
        'Ready' => :initializing,
        'Scheduled' => :initializing,
        'Running' => :running,
        'Aborted' => :deactivated,
        'Cancelled' => :deactivated,
        'Done.*' => :deactivated,
        'Cleared' => :deactivated
    }

    def self.map_status(status)
      matching_states = STATES_MAPPING.select do |reg_str, _|
        /#{reg_str}/ =~ status
      end
      matching_states.values.first
    end

    def status(ssh, job)
      PlGridScheduler.map_status(glite_state(ssh, job.job_id)) or :error
    end

    def cancel(ssh, record)
      PlGridScheduler.execute_glite_command(
          Command::cd_to_simulation_managers(cancel_sm_cmd(record)),
          ssh
      )
    end

    def cancel_sm_cmd(record)
      "glite-wms-job-cancel --no-int #{record.job_id}"
    end

    def clean_after_job(ssh, job)
      super
      ssh.exec!("rm #{job_jdl_file(job.sm_uuid)}")
    end

    def self.default_host
      'grid.cyf-kr.edu.pl'
    end

    def self.host_addresses
      {
        'dwarf.wcss.wroc.pl' => "dwarf.wcss.wroc.pl:8443/cream-pbs-plgrid", # wcss
        'grid.cyf-kr.edu.pl' => "cream.grid.cyf-kr.edu.pl:8443/cream-pbs-plgrid", # cyfronet
        'grid.icm.edu.pl' => "ce9.grid.icm.edu.pl:8443/cream-pbs-plgrid", # icm
        'grid.task.gda.pl' => "cream.grid.task.gda.pl:8443/cream-pbs-plgrid", # task
        'reef.man.poznan.pl' => "creamce.reef.man.poznan.pl:8443/cream-pbs-plgrid" # pcss
      }
    end

    def self.available_hosts
      [
        'dwarf.wcss.wroc.pl',
        'grid.cyf-kr.edu.pl',
        'grid.icm.edu.pl',
        'grid.task.gda.pl',
        'reef.man.poznan.pl'
      ]
    end

    def prepare_job_descriptor(uuid, params)
      log_path = PlGridJob.log_path(uuid)
      <<-eos
  Executable = "scalarm_job_#{uuid}.sh";
  Arguments = "#{uuid}";
  StdOutput = "#{log_path}";
  StdError = "#{log_path}";
  OutputSandbox = {"#{log_path}"};
  InputSandbox = {"scalarm_job_#{uuid}.sh", "scalarm_simulation_manager_#{uuid}.zip"};
  Requirements = (other.GlueCEUniqueID == "#{self.class.host_addresses[(params['plgrid_host'] or self.class.default_host)]}");
  VirtualOrganisation = "vo.plgrid.pl";
      eos
    end

    # Not used now
    # def new_session?(ssh)
    #   if @last_ssh.equal? ssh
    #     true
    #   else
    #     @last_ssh = ssh
    #     false
    #   end
    # end

    # Not used because of stateless SSH session usage
    # def prepare_session(ssh)
    #   if new_session?(ssh)
    #     logger.debug 'initializing proxy'
    #     voms_proxy_init(ssh, 'vo.plgrid.pl')
    #   end
    # end

    def get_log(ssh, job)
      out_log = ssh.exec!(tail(get_glite_output_to_file(ssh, job), 25))

        <<-eos
--- gLite info ---
#{get_job_info(ssh, job.job_id)}
--- Simulation Manager log ---
#{out_log}
        eos
    end

    def get_glite_output_to_file(ssh, job)
      output = PlGridScheduler.execute_glite_command(
          Command::cd_to_simulation_managers("glite-wms-job-output --dir . #{job.job_id}"),
          ssh
      )
      output_dir = GliteScheduler::PlGridScheduler.parse_get_output(output)
      "#{output_dir}/#{job.log_path}"
    end

    def self.parse_get_output(output)
      match = output.match /retrieved and stored in the directory:\s+(\S+)/
      match ? match[1] : nil
    end

    def self.execute_glite_command(command, ssh)
      # Before proxy init, force to use X509 default certificate and key (from UI storage)
      # Because by default it could use KeyFS storage
      cmd = "unset X509_USER_CERT; unset X509_USER_KEY; voms-proxy-init --voms vo.plgrid.pl; #{command}"
      begin
        result = nil
        timeout 15 do
          result = ssh.exec! cmd
        end
        raise StandardError.new 'voms-proxy-init: No credentials found!' if result =~ /No credentials found!/
        return result
      rescue Timeout::Error
        raise StandardError.new 'Timeout executing voms-proxy-init - probably key has passphrase'
      end
    end

    def job_jdl_file(sm_uuid)
      "scalarm_job_#{sm_uuid}.jdl"
    end

  end

end