require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

require 'grid_schedulers/glite_facade'
require 'grid_schedulers/pbs_facade'

require_relative 'infrastructure_facade'

class PLGridFacade < InfrastructureFacade

  def initialize
    @ui_grid_host = 'ui.grid.cyfronet.pl'
  end

  def current_state(user)
    jobs = PlGridJob.find_all_by_user_id(user.id)
    jobs_count = if jobs.nil?
                   0
                 else
                   jobs.size
                 end

    "Currently #{jobs_count} jobs are scheduled or running."
  end

  # for each job check
  # 1. if the experiment is still running - destroy the job otherwise
  # 2. if the job is started correctly and is not stuck in a queue - restart if yes
  # 3. if the job is running more then 24 hours  - restart if yes
  def start_monitoring
    while true do
      sleep(1) until MongoLock.acquire('PlGridJob')

      begin
        Rails.logger.info("[plgrid] #{Time.now} - monitoring thread is working")
        #  group jobs by the user_id - for each group - login to the ui using the user credentials
        PlGridJob.all.group_by(&:user_id).each do |user_id, job_list|

          credentials = GridCredentials.find_by_user_id(user_id)

          Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
            job_list.each do |job|
              scheduler = create_scheduler_facade(job.scheduler_type)
              ssh.exec!('voms-proxy-init --voms vo.plgrid.pl') if job.scheduler_type == 'glite' # generate new proxy if glite
              experiment = Experiment.find_by_id(job.experiment_id)

              all, sent, done = experiment.get_statistics unless experiment.nil?

              Rails.logger.info("Experiment: #{job.experiment_id} --- nil?: #{experiment.nil?}")

              if experiment.nil? or (not experiment.is_running) or (experiment.experiment_size == done)
                Rails.logger.info("Experiment '#{job.experiment_id}' is no longer running => destroy the job and temp password")
                destroy_and_clean_after(job, scheduler, ssh)

              #  if the job is not running although it should (create_at + 10.minutes > Time.now) - restart = cancel + start
              elsif scheduler.is_job_queued(ssh, job) and (job.created_at + 10.minutes < Time.now)

                Rails.logger.info("#{Time.now} - the job will be restarted due to not been run")
                scheduler.restart(ssh, job)

              elsif job.created_at + 24.hours < Time.now
                #  if the job is running more than 24 h then restart
                Rails.logger.info("#{Time.now} - the job will be restarted due to being run for 24 hours")
                scheduler.restart(ssh, job)

              elsif scheduler.is_done(ssh, job) or (job.created_at + job.time_limit.minutes < Time.now)
                Rails.logger.info("#{Time.now} - the job is done or should be already done - so we will destroy it")
                scheduler.cancel(ssh, job)
                destroy_and_clean_after(job, scheduler, ssh)
              end
            end
          end
        end
      rescue Exception => e
        Rails.logger.error("[plgrid] An exception occured in the monitoring thread --- #{e}")
      end
      
      MongoLock.release('PlGridJob')      
      sleep(60)
    end
  end

  def destroy_and_clean_after(job, scheduler, ssh)
    Rails.logger.info("Destroying temp pass for #{job.sm_uuid}")
    temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(job.sm_uuid)
    Rails.logger.info("It is nil ? --- #{temp_pass.nil?}")
    temp_pass.destroy unless temp_pass.nil? || temp_pass.longlife
    job.destroy
    scheduler.clean_after_job(ssh, job)
  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    sm_uuid = SecureRandom.uuid
    scheduler = create_scheduler_facade(additional_params['scheduler'])

    # prepare locally code of a simulation manager to upload with a configuration file
    prepare_configuration_for_simulation_manager(sm_uuid, user.id, experiment_id, additional_params['start_at'])

    if credentials = GridCredentials.find_by_user_id(user.id)
      # prepare job executable and descriptor
      scheduler.prepare_job_files(sm_uuid)

      #  upload the code to the Grid user interface machine
      begin
        Net::SCP.start(credentials.host, credentials.login, password: credentials.password) do |scp|
          scheduler.send_job_files(sm_uuid, scp)
        end

        Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
          1.upto(instances_count).each do
            #  retrieve job id and store it in the database for future usage
            job = PlGridJob.new({ 'user_id' => user.id, 'experiment_id' => experiment_id, 'created_at' => Time.now,
                                  'scheduler_type' => additional_params['scheduler'], 'sm_uuid' => sm_uuid,
                                  'time_limit' => additional_params['time_limit'].to_i })
            job.grant_id = additional_params['grant_id'] unless additional_params['grant_id'].blank?

            if scheduler.submit_job(ssh, job)
              job.save
            else
              return 'error', 'Could not submit job'
            end
          end
        end
      rescue Net::SSH::AuthenticationFailed => auth_exception
        return 'error', I18n.t('plgrid.job_submission.authentication_failed', ex: auth_exception)
      rescue Exception => ex
        return 'error', I18n.t('plgrid.job_submission.error', ex: ex)
      end

      return 'ok', I18n.t('plgrid.job_submission.ok', instances_count: instances_count)
    else
      return 'error', I18n.t('plgrid.job_submission.no_credentials')
    end
  end

  def stop_simulation_managers(user, instances_count, experiment = nil)
    raise 'not implemented'
  end

  def get_running_simulation_managers(user, experiment = nil)
    PlGridJob.find_all_by_user_id(user.id)
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

  def retrieve_grants(credentials)
    return [] if credentials.nil?

    grants, grant_output = [], []

    begin
      Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
        grant_output = ssh.exec!('plg-show-grants').split("\n").select{|line| line.start_with?('|')}
      end

      grant_output.each do |line|
        grant_id = line.split('|')[1].strip
        grants << grant_id.split('(*)').first.strip unless grant_id.include?('GrantID')
      end
    rescue Exception => e
      Rails.logger.error("Could not read user's grants - #{e}")
    end

    grants
  end

end