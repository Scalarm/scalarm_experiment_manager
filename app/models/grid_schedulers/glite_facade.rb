class GliteFacade

  def prepare_job_files(sm_uuid)
    IO.write("/tmp/scalarm_job_#{sm_uuid}.sh", prepare_job_executable)
    IO.write("/tmp/scalarm_job_#{sm_uuid}.jdl", prepare_job_descriptor(sm_uuid))
  end

  def send_job_files(sm_uuid, scp)
    scp.upload! "/tmp/scalarm_simulation_manager_#{sm_uuid}.zip", '.'
    scp.upload! "/tmp/scalarm_job_#{sm_uuid}.sh", '.'
    scp.upload! "/tmp/scalarm_job_#{sm_uuid}.jdl", '.'
  end

  def submit_job(ssh, job)
    ssh.exec!("chmod a+x scalarm_job_#{job.sm_uuid}.sh")
    #  create a proxy certificate for the user
    ssh.exec!('voms-proxy-init --voms vo.plgrid.pl')
    #  schedule the job with glite wms

    #  schedule the job with glite wms
    submit_job_output = ssh.exec!("glite-wms-job-submit -a scalarm_job_#{job.sm_uuid}.jdl")
    Rails.logger.debug("Output lines: #{submit_job_output}")

    if submit_job_output != nil
      output_lines = submit_job_output.split("\n")

      output_lines.each_with_index do |line, index|
        if line.include?('Your job identifier is:')
          if output_lines[index + 1].start_with?('http')
            job.job_id = output_lines[index + 1]
            return true
          elsif output_lines[index + 2].start_with?('http')
            job.job_id = output_lines[index + 2]
            return true
          end
        end
      end
    end

    false
  end

  def current_state(ssh, job)
    state_output = ssh.exec!("glite-wms-job-status #{job.job_id}")
    current_state_line = state_output.split("\n").select{|line| line.start_with?('Current Status:')}.first

    current_state_line['Current Status:'.length..-1].strip
  end

  def is_done(ssh, job)
    not %w(Ready Scheduled Running).include?(current_state(ssh, job))
  end

  def is_job_queued(ssh, job)
    %w(Ready Scheduled).include?(current_state(ssh, job))
  end

  def cancel(ssh, job)
    ssh.open_channel do |channel|
      channel.send_data("glite_wms_job-cancel #{job.job_id}")
      channel.send_data('y')
      channel.close
    end
  end

  def clean_after_job(ssh, job)
    ssh.exec!("rm scalarm_simulation_manager_#{job.sm_uuid}.zip")
    ssh.exec!("rm scalarm_job_#{job.sm_uuid}.sh")
    ssh.exec!("rm scalarm_job_#{job.sm_uuid}.jdl")
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

  # wcss - "dwarf.wcss.wroc.pl:8443/cream-pbs-plgrid"
  # cyfronet - "cream.grid.cyf-kr.edu.pl:8443/cream-pbs-plgrid"
  # icm - "ce9.grid.icm.edu.pl:8443/cream-pbs-plgrid"
  def prepare_job_descriptor(uuid)
    <<-eos
Executable = "scalarm_job_#{uuid}.sh";
Arguments = "#{uuid}";
StdOutput = "scalarm_job.out";
StdError = "scalarm_job.err";
OutputSandbox = {"scalarm_job.out", "scalarm_job.err"};
InputSandbox = {"scalarm_job_#{uuid}.sh", "scalarm_simulation_manager_#{uuid}.zip"};
Requirements = (other.GlueCEUniqueID == "dwarf.wcss.wroc.pl:8443/cream-pbs-plgrid" || other.GlueCEUniqueID == "ce9.grid.icm.edu.pl:8443/cream-pbs-plgrid");
    eos
  end

  def prepare_job_executable
    <<-eos
#!/bin/bash
module add plgrid/tools/ruby/2.0.0-p0

#if [[ -n "$TMPDIR" ]]; then echo $TMPDIR; cd $TMPDIR; fi

unzip scalarm_simulation_manager_$1.zip
cd scalarm_simulation_manager_$1
ruby simulation_manager.rb
    eos
  end

end