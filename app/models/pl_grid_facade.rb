require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

require 'grid_schedulers/glite_facade'
require 'grid_schedulers/pbs_facade'

class PLGridFacade < InfrastructureFacade

  def initialize
    @ui_grid_host = 'ui.grid.cyfronet.pl'
  end

  def current_state(user_id)
    jobs = PlGridJob.find_all_by_user_id(user_id)
    jobs_count = if jobs.nil?
                   0
                 else
                   jobs.size
                 end

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
            scheduler = create_scheduler_facade(job.scheduler_type)
            #Rails.logger.debug("#{Time.now} - checking job #{job.job_id} - current state #{scheduler.current_state(ssh, job)}")
            #Rails.logger.debug("Is job scheduled --- #{scheduler.is_job_queued(ssh, job)}")
            #Rails.logger.debug("Too long scheduled --- #{(job.created_at + 10.minutes < Time.now)} --- #{job.created_at} --- #{job.created_at + 10.minutes} --- #{Time.now}")
            #Rails.logger.debug("Too long running --- #{(job.created_at + 24.hours < Time.now)}")
            #Rails.logger.debug("Experiment is valid --- #{((not job.experiment.nil?) and (not job.experiment.is_completed))}")
            #Rails.logger.debug("Experiment is not valid --- #{not job.experiment_id.blank? and DataFarmingExperiment.find_by_experiment_id(job.experiment_id).nil?}")

            #  if the job is not running although it should (create_at + 10.minutes > Time.now) - restart = cancel + start
            if scheduler.is_job_queued(ssh, job) and (job.created_at + 10.minutes < Time.now)
              Rails.logger.debug("#{Time.now} - the job will be restarted due to not been run --- #{not job.experiment_id.blank?} --- #{DataFarmingExperiment.find_by_experiment_id(job.experiment_id).nil?}")
              # but first check if the experiment which should be calculated still exists
              if not job.experiment_id.blank? and DataFarmingExperiment.find_by_experiment_id(job.experiment_id).nil?
                Rails.logger.debug('The experiment which should be computed no longer exists')
                job.destroy
              else
                if scheduler.restart(ssh, job)
                  job.created_at = Time.now
                  job.save
                end
              end

            elsif (job.created_at + 24.hours < Time.now) and ((not job.experiment.nil?) and (not job.experiment.is_completed))
              #  if the job is running more than 24 h then restart
              Rails.logger.debug("#{Time.now} - the job will be restarted due to being run for 24 hours")

              # but first check if the experiment which should be calculated still exists
              if not job.experiment_id.blank? and DataFarmingExperiment.find_by_experiment_id(job.experiment_id).nil?
                Rails.logger.debug('The experiment which should be computed no longer exists')
                job.destroy
              else
                if scheduler.restart(ssh, job)
                  job.created_at = Time.now
                  job.save
                end
              end

            elsif scheduler.is_done(ssh, job) or (job.created_at + job.time_limit.minutes < Time.now)
              Rails.logger.debug("#{Time.now} - the job is done or should be already done - so we will destroy it")
              scheduler.cancel(ssh, job)
              job.destroy
              scheduler.clean_after_job(ssh, job)
            end
          end
        end
      end

      sleep(60)
    end

  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    sm_uuid = SecureRandom.uuid
    scheduler = create_scheduler_facade(additional_params['scheduler'])

    # prepare locally code of a simulation manager to upload with a configuration file
    prepare_configuration_for_simulation_manager(sm_uuid, user, experiment_id)

    if credentials = GridCredentials.find_by_user_id(user.id)
      # prepare job executable and descriptor
      scheduler.prepare_job_files(sm_uuid)

      #  upload the code to the Grid user interface machine
      Net::SCP.start(credentials.host, credentials.login, password: credentials.password) do |scp|
        scheduler.send_job_files(sm_uuid, scp)
      end

      Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
        1.upto(instances_count).each do
          #  retrieve job id and store it in the database for future usage
          job = PlGridJob.new({ 'user_id' => user.id, 'experiment_id' => experiment_id, 'created_at' => Time.now,
                                'scheduler_type' => additional_params['scheduler'], 'sm_uuid' => sm_uuid,
                                'time_limit' => additional_params['time_limit'].to_i })

          if scheduler.submit_job(ssh, job)
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

  def add_credentials(user, params, session)
    credentials = GridCredentials.find_by_user_id(user.id)

    if credentials
      credentials.login = params[:username]
      credentials.password = params[:password]
      credentials.host = params[:host]
    else
      credentials = GridCredentials.new({ 'user_id' => user.id, 'host' => params[:host], 'login' => params[:username] })
      credentials.password = params[:password]
    end

    if params[:save_settings] == 'false'
      session[:tmp_plgrid_credentials] = true
    else
      session.delete(:tmp_plgrid_credentials)
    end

    credentials.save

    'ok'
  end

  def clean_tmp_credentials(user_id, session)
    if session.include?(:tmp_plgrid_credentials)
      GridCredentials.find_by_user_id(user_id).destroy
    end
  end

  def create_scheduler_facade(type)
    if type == 'qsub'
      PBSFacade.new
    elsif type == 'glite'
      GliteFacade.new
    end
  end

  def default_additional_params
    { 'scheduler' => 'qsub', 'time_limit' => 300 }
  end

end