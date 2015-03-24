# Subclasses must implement:
# - short_name() -> String
# - long_name() -> String
# - prepare_job_files(sm_uuid, params) - wrtie files to '/tmp' needed to send to UI
# - tmp_job_files_list -> Array of file names to transfer from EM server to UI
#    - should be list of files generated in prepare_job_files
#    - _without_ simulation manager ZIP package
# - submit_job(ssh, job) - submit job and return job id; if submission fails raise JobSubmissionFailed
# - prepare_sesion(ssh) - prepare UI user account to run jobs - eg. init proxy
# - cancel(ssh, record) - cancels job
# - status(ssh, record) -> job state in queue mapped to: :initializing, :running, :deactivated, :error
# - clean_after_job(ssh, record) - cleans UI user's account from temporary files
# - get_log(ssh, record) -> String with stdout+stderr contents for job

require 'infrastructure_facades/shell_commands'
require 'infrastructure_facades/ssh_accessed_infrastructure'

require 'timeout'

class JobSubmissionFailed < StandardError; end

class PlGridSchedulerBase
  include ShellCommands
  include SSHAccessedInfrastructure

  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def prepare_session(ssh)
    # pass
  end

  def end_session(ssh)
    # pass
  end

  def onsite_monitorable?
    false
  end

  def prepare_job_executable
    if Rails.configuration.simulation_manager_version == :go
    <<-eos
#!/bin/bash

if [[ -n "$TMPDIR" ]]; then echo $TMPDIR; cp scalarm_simulation_manager_$1.zip $TMPDIR/;  cd $TMPDIR; fi

unzip scalarm_simulation_manager_$1.zip
cd scalarm_simulation_manager_$1
unxz scalarm_simulation_manager.xz
chmod a+x scalarm_simulation_manager
./scalarm_simulation_manager
    eos
    elsif Rails.configuration.simulation_manager_version == :ruby
      <<-eos
#!/bin/bash
module add plgrid/tools/ruby/2.0.0-p0

if [[ -n "$TMPDIR" ]]; then echo $TMPDIR; cp scalarm_simulation_manager_$1.zip $TMPDIR/;  cd $TMPDIR; fi

unzip scalarm_simulation_manager_$1.zip
cd scalarm_simulation_manager_$1
ruby simulation_manager.rb
      eos
    end
  end

  def create_tmp_job_files(sm_uuid, params)
    begin
      prepare_job_files(sm_uuid, params)
      yield
    ensure
      tmp_job_files_list(sm_uuid).each { |f| FileUtils.rm_rf(f) } if block_given?
    end
  end

  def clean_after_job(ssh, job)
    ssh.exec!(clean_after_sm_cmd(job))
  end

  #  Initialize VOMS-extended proxy certificate for the user
  def voms_proxy_init(ssh, voms)
    begin
      result = nil
      timeout 10 do
        # Before proxy init, force to use X509 default certificate and key (from UI storage)
        # Because by default it could use KeyFS storage
        result = ssh.exec!("unset X509_USER_CERT; unset X509_USER_KEY; voms-proxy-init --voms #{voms}")
      end
      raise StandardError.new 'voms-proxy-init: No credentials found!' if result =~ /No credentials found!/
    rescue Timeout::Error
      raise StandardError.new 'Timeout executing voms-proxy-init - probably key has passphrase'
    end
  end

  def restart(ssh, job)
    cancel(ssh, job)
    job.job_id = submit_job(ssh, job)
    job.save
  end

  def clean_after_sm_cmd(record)
    sm_uuid = record.sm_uuid
    chain(
      rm(ScalarmFileName::tmp_sim_zip(sm_uuid)),
      rm(File.join(RemoteDir::scalarm_root, job_script_file(sm_uuid)), true)
    )
  end

  def restart_sm_cmd(record)
    chain(
      cancel_sm_cmd(record),
      submit_job_cmd(record)
    )
  end

  def send_job_files(sm_uuid, scp)
    sim_path = LocalAbsolutePath::tmp_sim_zip(sm_uuid)
    scp.upload_multiple! [sim_path]+tmp_job_files_list(sm_uuid), RemoteDir::scalarm_root
  end

  def job_script_file(sm_uuid)
    "scalarm_job_#{sm_uuid}.sh"
  end

end
