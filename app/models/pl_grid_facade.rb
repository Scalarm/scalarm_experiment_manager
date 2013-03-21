require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

class PLGridFacade < InfrastructureFacade

  def initialize
    @ui_grid_host = 'ui.grid.cyfronet.pl'
  end

  def start_simulation_managers(user, instances_count, experiment_id)
    sm_uuid = SecureRandom.uuid
    # prepare locally code of a simulation manager to upload with a configuration file
    prepare_configuration_for_simulation_manager(sm_uuid, user, experiment_id)
    # prepare job executable and descriptor
    IO.write("/tmp/scalarm_job_#{sm_uuid}.sh", prepare_job_executable)
    IO.write("/tmp/scalarm_job_#{sm_uuid}.jdl", prepare_job_descriptor(sm_uuid))

    if credentials = user.grid_credentials
      #  upload the code to the Grid user interface machine
      Net::SCP.start(credentials.host, credentials.login, password: credentials.password) do |scp|
        scp.upload! "/tmp/scalarm_simulation_manager_#{sm_uuid}.zip", '.'
        scp.upload! "/tmp/scalarm_job_#{sm_uuid}.sh", '.'
        scp.upload! "/tmp/scalarm_job_#{sm_uuid}.jdl", '.'
      end

      Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
        ssh.exec!("chmod a+x scalarm_job_#{sm_uuid}.sh")
        #  create a proxy certificate for the user
        ssh.exec!('voms-proxy-init --voms vo.plgrid.pl')
        #  schedule the job with glite wms
        1.upto(instances_count).each do
          #  retrieve job id and store it in the database for future usage
          if job_id = submit_job(ssh, sm_uuid)
            job = PlGridJob.new({ user_id: user.id, job_id: job_id, created_at: Time.now })
            job.save
          else
            return 'error', 'Could not submit job'
          end
        end

        return 'ok', "You have scheduled #{instances_count} jobs"
      end
    else
      return 'error', 'You have to provide Grid credentials first!'
    end
  end

  def stop_simulation_managers(user, instances_count, experiment = nil)
    raise 'not implemented'
  end

  def get_running_simulation_managers_count(user, experiment = nil)
    PlGridJob.find_by_user_id(user.id).size
  end

  def prepare_job_descriptor(uuid)
    <<-eos
      Executable = "scalarm_job_#{uuid}.sh";
      Arguments = "#{uuid}";
      StdOutput = "scalarm_job.out";
      StdError = "scalarm_job.err";
      OutputSandbox = {"scalarm_job.out", "scalarm_job.err"};
      InputSandbox = {"scalarm_job_#{uuid}.sh", "scalarm_simulation_manager_#{uuid}.zip"};
      Requirements = other.GlueCEUniqueID == "cream.grid.cyf-kr.edu.pl:8443/cream-pbs-plgrid";
    eos
  end

  def prepare_job_executable
    <<-eos
      #!/bin/bash
      module add ruby/1.9.1-p376.sl4

      unzip scalarm_simulation_manager_$1.zip
      cd scalarm_simulation_manager_$1
      ruby simulation_manager.rb
    eos
  end

  def submit_job(ssh, sm_uuid)
    submit_job_output = ssh.exec!("glite-wms-job-submit -a scalarm_job_#{sm_uuid}.jdl")
    Rails.logger.debug("Output lines: #{submit_job_output}")

    if submit_job_output != nil
      output_lines = submit_job_output.split("\n")

      output_lines.each_with_index do |line, index|
        if line.include?('Your job identifier is:')
          return output_lines[index + 1] if output_lines[index + 1].start_with?('http')
          return output_lines[index + 2] if output_lines[index + 2].start_with?('http')
        end
      end
    end

    nil
  end

end