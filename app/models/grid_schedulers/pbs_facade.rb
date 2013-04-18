class PBSFacade

  def prepare_job_files(sm_uuid)
    IO.write("/tmp/scalarm_job_#{sm_uuid}.sh", prepare_job_executable)
  end

  def send_job_files(sm_uuid, scp)
    scp.upload! "/tmp/scalarm_simulation_manager_#{sm_uuid}.zip", '.'
    scp.upload! "/tmp/scalarm_job_#{sm_uuid}.sh", '.'
  end

  def submit_job(ssh, job)
    ssh.exec!("chmod a+x scalarm_job_#{job.sm_uuid}.sh")
    #  create a proxy certificate for the user
    ssh.exec!('voms-proxy-init --voms vo.plgrid.pl')
    #  schedule the job with qsub
    submit_job_output = ssh.exec!("echo \"sh scalarm_job_#{job.sm_uuid}.sh #{job.sm_uuid}\" | qsub -q plgrid")
    Rails.logger.debug("Output lines: #{submit_job_output}")

    if submit_job_output != nil
      output_lines = submit_job_output.split("\n")

      output_lines.each do |line|
        # checking if the first element is integer -> it is the identifier we are looking for
        if line[0].to_i.to_s == line[0]
          job.job_id = line.strip
          return true
        end
      end
    end

    false
  end

  def current_state(ssh, job)
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

  def is_done(ssh, job)
    %w(C).include?(current_state(ssh, job))
  end

  def is_job_queued(ssh, job)
    %w(Q T W).include?(current_state(ssh, job))
  end

  def cancel(ssh, job)
    ssh.exec!("qdel #{job.job_id}")
  end

  def clean_after_job(ssh, job)
    ssh.exec!("rm scalarm_simulation_manager_#{job.sm_uuid}.zip")
    ssh.exec!("rm scalarm_job_#{job.sm_uuid}.sh")
  end

  def restart(ssh, job)
    cancel(ssh, job)
    if submit_job(ssh, job)
      job.save
      true
    else
      false
    end
  end

  def prepare_job_executable
    <<-eos
#!/bin/bash

unzip scalarm_simulation_manager_$1.zip
cd scalarm_simulation_manager_$1
ruby simulation_manager.rb
    eos
  end
end