require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

class PLGridFacade < InfrastructureFacade

  def initialize
    @ui_grid_host = 'ui.grid.cyfronet.pl'
  end

  def current_state(user_id)
    jobs = PlGridJob.find_by_user_id(user_id)
    jobs_count = jobs.nil? ? 0 : jobs.size

    "Currently #{jobs_count} jobs are scheduled or running."
  end

  def start_monitoring
    while true do
      Rails.logger.debug("#{Time.now} - PLGrid monitoring thread is working")
    #  group jobs by the user_id
      jobs = PlGridJob.all.group_by(&:user_id)
    #  for each group - login to the ui using the user credentials
      jobs.each do |user_id, job_list|
        credentials = GridCredentials.find_by_user_id(user_id)
        Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
          # generate new proxy
          ssh.exec!('voms-proxy-init --voms vo.plgrid.pl')
          job_list.each do |job|
            Rails.logger.debug("#{Time.now} - checking job #{job} - current state #{job.current_state(ssh)}")

            #  if the job is not running although it should (create_at + 10.minutes > Time.now) - restart = cancel + start
            if %w(Ready Scheduled).include?(job.current_state(ssh)) and (job.created_at + 10.minutes < Time.now)
              Rails.logger.debug("#{Time.now} - the job will be restarted due to not been run")

              if job.restart(ssh)
                job.created_at = Time.now
                job.save
              end

            elsif (job.created_at + 24.hours < Time.now) and ((not job.experiment.nil?) and (not job.experiment.is_completed))
              #  if the job is running more than 24 h then restart
              Rails.logger.debug("#{Time.now} - the job will be restarted due to being run for 24 hours")
              if job.restart(ssh)
                job.created_at = Time.now
                job.save
              end

            elsif job.is_done(ssh) or (job.created_at + job.time_limit.minutes < Time.now)
              Rails.logger.debug("#{Time.now} - the job is done or should be already done - so we will destroy it")
              job.cancel(ssh)
              job.destroy
            end
          end
        end
      end

      sleep(60)
    end

  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
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
          job = PlGridJob.new({ 'user_id' => user.id, 'experiment_id' => experiment_id, 'created_at' => Time.now,
                                'sm_uuid' => sm_uuid, 'time_limit' => additional_params[:time_limit].to_i })
          if job.submit(ssh)
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
    jobs = PlGridJob.find_by_user_id(user.id)
    jobs.nil? ? 0 : jobs.size
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

end