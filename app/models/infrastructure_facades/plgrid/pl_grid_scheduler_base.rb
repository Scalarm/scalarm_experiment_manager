# Subclasses must implement:
# - short_name() -> String
# - long_name() -> String
# - prepare_job_files(sm_uuid, params) - wrtie files to '/tmp' needed to send to UI
# - send_job_files(sm_uuid, scp)
# - submit_job(ssh, job)
# - prepare_sesion(ssh) - prepare UI user account to run jobs - eg. init proxy
# - cancel(ssh, record) - cancels job
# - status(ssh, record) -> job state in queue mapped to: :initializing, :running, :deactivated, :error
# - clean_after_job(ssh, record) - cleans UI user's account from temporary files
# - get_log(ssh, record) -> String with stdout+stderr contents for job

class PlGridSchedulerBase

  def prepare_session(ssh)
    # pass
  end

  def end_session(ssh)
    # pass
  end

  def prepare_job_executable
    <<-eos
#!/bin/bash
module add plgrid/tools/ruby/2.0.0-p0

if [[ -n "$TMPDIR" ]]; then echo $TMPDIR; cp scalarm_simulation_manager_$1.zip $TMPDIR/;  cd $TMPDIR; fi

unzip scalarm_simulation_manager_$1.zip
cd scalarm_simulation_manager_$1
ruby simulation_manager.rb
    eos
  end

  def clean_after_job(ssh, job)
    ssh.exec!("rm scalarm_simulation_manager_#{job.sm_uuid}.zip")
    ssh.exec!("rm scalarm_job_#{job.sm_uuid}.sh")
  end

  #  Create a proxy certificate for the user
  def voms_proxy_init(ssh, voms)
    ssh.exec!("voms-proxy-init --voms #{voms}")
  end

  def restart(ssh, job)
    cancel(ssh, job)
    submit_job(ssh, job)
  end

end
