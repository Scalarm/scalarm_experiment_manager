require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

require 'plgrid/grid_schedulers/glite_facade'
require 'plgrid/grid_schedulers/pbs_facade'

require_relative 'infrastructure_facade'

class PlGridFacade < InfrastructureFacade

  def initialize
    super()
    @ui_grid_host = 'ui.grid.cyfronet.pl'
  end

  def long_name
    'PL-Grid'
  end

  def short_name
    'plgrid'
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

      # FIXME monitoring disabled for desiging tree
      #begin
      #  logger.info "monitoring thread is working"
      #  #  group jobs by the user_id - for each group - login to the ui using the user credentials
      #  PlGridJob.all.group_by(&:user_id).each do |user_id, job_list|
      #    credentials = GridCredentials.find_by_user_id(user_id)
      #    next if job_list.blank? or credentials.nil? # we cannot monitor due to secrets lacking...
      #
      #    Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
      #      (job_list.map {|job| PlGridSimulationManager.new(job, ssh)}).each &:monitor
      #    end
      #
      #  end
      #rescue Exception => e
      #  logger.error "Monitoring exception: #{e}\n#{e.backtrace.join("\n")}"
      #end
      
      MongoLock.release('PlGridJob')      
      sleep(60)
    end
  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    sm_uuid = SecureRandom.uuid
    scheduler = self.class.create_scheduler_facade(additional_params['scheduler'])

    # prepare locally code of a simulation manager to upload with a configuration file
    InfrastructureFacade.prepare_configuration_for_simulation_manager(sm_uuid, user.id, experiment_id, additional_params['start_at'])

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

    credentials.save

    'ok'
  end

  def clean_tmp_credentials(user_id, session)
  end

  def self.scheduler_facade_classes
    Hash[[PBSFacade, GliteFacade].map {|f| [f.short_name, f]}]
  end

  def self.scheduler_facades
    Hash[(scheduler_facade_classes.map {|name, cls| [name, cls.new]})]
  end

  def self.create_scheduler_facade(type)
    scheduler_facade_classes[type].new
  end

  def default_additional_params
    { 'scheduler' => 'qsub', 'time_limit' => 300 }
  end

  # Overrides
  def sm_containers
    self.class.scheduler_facades.values
  end

  # Overrides
  def to_hash
    {
        name: long_name,
        type: 'meta-node',
        short: short_name,
        children: self.class.scheduler_facade_classes.values.map { |sched_facade|
          {
              name: sched_facade.long_name,
              type: 'sm-container-node',
              short: sched_facade.short_name
          }
        }
    }
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