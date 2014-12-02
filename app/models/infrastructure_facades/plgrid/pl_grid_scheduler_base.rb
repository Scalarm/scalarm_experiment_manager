# Subclasses must implement:
# - short_name() -> String
# - long_name() -> String
# - prepare_job_files(sm_uuid, params) - wrtie files to '/tmp' needed to send to UI
# - send_job_files(sm_uuid, scp)
# - submit_job(ssh, job) - submit job and return job id; if submission fails raise JobSubmissionFailed
# - prepare_sesion(ssh) - prepare UI user account to run jobs - eg. init proxy
# - cancel(ssh, record) - cancels job
# - status(ssh, record) -> job state in queue mapped to: :initializing, :running, :deactivated, :error
# - clean_after_job(ssh, record) - cleans UI user's account from temporary files
# - get_log(ssh, record) -> String with stdout+stderr contents for job

require 'timeout'

class JobSubmissionFailed < StandardError; end

class PlGridSchedulerBase
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
    submit_job(ssh, job)
  end

  def clean_after_sm_cmd(record)
    [
      "rm scalarm_simulation_manager_#{record.sm_uuid}.zip",
      "rm scalarm_job_#{record.sm_uuid}.sh"
    ].join(';')
  end

  def restart_sm_cmd(record)
    [
      cancel_sm_cmd(record),
      submit_job_cmd(record)
    ].join(';')
  end

end
