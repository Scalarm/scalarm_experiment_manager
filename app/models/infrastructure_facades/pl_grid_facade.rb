require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

require 'plgrid/grid_schedulers/glite_facade'
require 'plgrid/grid_schedulers/pbs_facade'

require_relative 'infrastructure_facade'
require_relative 'shared_ssh'

class PlGridFacade < InfrastructureFacade
  include SharedSSH

  attr_reader :ssh_sessions

  def initialize
    super()
    @ui_grid_host = 'ui.grid.cyfronet.pl'
    @ssh_sessions = {}
  end

  def long_name
    'PL-Grid'
  end

  def short_name
    'plgrid'
  end

  def current_state(user)
    jobs = get_sm_records(user.id)
    I18n.t('infrastructure_facades.plgrid.current_state', jobs_count: jobs.nil? ? 0 : jobs.size)
  end

  # TODO: group by user_id
  # # for each job check
  # # 1. if the experiment is still running - destroy the job otherwise
  # # 2. if the job is started correctly and is not stuck in a queue - restart if yes
  # # 3. if the job is running more then 24 hours  - restart if yes
  # def monitoring_loop
  #   #  group jobs by the user_id - for each group - login to the ui using the user credentials
  #   PlGridJob.all.group_by(&:user_id).each do |user_id, job_list|
  #
  #     begin
  #       logger.info "monitoring thread is working"
  #       #  group jobs by the user_id - for each group - login to the ui using the user credentials
  #       PlGridJob.all.group_by(&:user_id).each do |user_id, job_list|
  #         credentials = GridCredentials.find_by_user_id(user_id)
  #         next if job_list.blank? or credentials.nil? # we cannot monitor due to secrets lacking...
  #
  #         Net::SSH.start(credentials.host, credentials.login, password: credentials.password) do |ssh|
  #           (job_list.map {|job| PlGridSimulationManager.new(job, ssh)}).each &:monitor
  #         end
  #       end
  #     end
  #   end
  # end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    sm_uuid = SecureRandom.uuid
    scheduler = self.class.create_scheduler_facade(additional_params['scheduler'].to_s)

    # prepare locally code of a simulation manager to upload with a configuration file
    InfrastructureFacade.prepare_configuration_for_simulation_manager(sm_uuid, user.id, experiment_id, additional_params['start_at'])

    if credentials = GridCredentials.find_by_user_id(user.id)
      # prepare job executable and descriptor
      scheduler.prepare_job_files(sm_uuid)

      #  upload the code to the Grid user interface machine
      begin
        credentials.scp_start do |scp|
          scheduler.send_job_files(sm_uuid, scp)
        end

        credentials.ssh_start do |ssh|
          1.upto(instances_count).each do
            #  retrieve job id and store it in the database for future usage
            job = PlGridJob.new({ 'user_id' => user.id, 'experiment_id' => experiment_id,
                                  'scheduler_type' => additional_params['scheduler'], 'sm_uuid' => sm_uuid,
                                  'time_limit' => additional_params['time_limit'].to_i })
            job.grant_id = additional_params['grant_id'] unless additional_params['grant_id'].blank?
            job.nodes = additional_params['nodes'] unless additional_params['nodes'].blank?
            job.ppn = additional_params['ppn'] unless additional_params['ppn'].blank?
            job.initialize_fields

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

  def remove_credentials(record_id, user_id, params=nil)
    record = GridCredentials.find_by_id(record_id)
    raise InfrastructureErrors::NoCredentialsError if record.nil?
    raise InfrastructureErrors::AccessDeniedError if record.user_id != user_id
    record.destroy
  end

  def clean_tmp_credentials(user_id, session)
  end

  def self.scheduler_facade_classes
    Hash[[PBSFacade, GliteFacade].map {|f| [f.short_name.to_sym, f]}]
  end

  def self.scheduler_facades
    Hash[scheduler_facade_classes.map {|name, cls| [name, cls.new]}]
  end

  def self.create_scheduler_facade(type)
    scheduler_facade_classes[type.to_sym].new
  end

  # Overrides InfrastructureFacade method
  def to_h
    {
        name: long_name,
        children: self.class.scheduler_facades.values.map do |scheduler|
            {
                name: scheduler.long_name,
                infrastructure_name: short_name,
                infrastructure_params: {scheduler_type: scheduler.short_name}
            }
        end
    }
  end

  def get_sm_records(user_id=nil, experiment_id=nil, params={})
    query = (user_id ? {user_id: user_id} : {})
    query.merge!({experiment_id: experiment_id}) if experiment_id
    query.merge!({scheduler_type: params[:scheduler_type]}) if params[:scheduler_type]
    PlGridJob.find_all_by_query(query)
  end

  def get_sm_record_by_id(record_id)
    PlGridJob.find_by_id(record_id)
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

  # -- SimulationManager delegation methods --

  def simulation_manager_before_monitor(record)
    PlGridFacade.create_scheduler_facade(record.scheduler_type).prepare_session(shared_ssh_session(record.credentials))
  end

  def simulation_manager_stop(record)
    scheduler = PlGridFacade.create_scheduler_facade(record.scheduler_type)
    ssh = shared_ssh_session(record.credentials)
    scheduler.cancel(ssh, record)
    scheduler.clean_after_job(ssh, record)
  end

  def simulation_manager_restart(record)
    scheduler = PlGridFacade.create_scheduler_facade(record.scheduler_type)
    ssh = shared_ssh_session(record.credentials)
    scheduler.restart(ssh, record)
  end

  def simulation_manager_status(record)
    scheduler = PlGridFacade.create_scheduler_facade(record.scheduler_type)
    ssh = shared_ssh_session(record.credentials)
    scheduler.status(ssh, record)
  end

  def simulation_manager_running?(record)
    scheduler = PlGridFacade.create_scheduler_facade(record.scheduler_type)
    ssh = shared_ssh_session(record.credentials)
    not scheduler.is_done(ssh, record)
  end

  def simulation_manager_get_log(record)
    scheduler = PlGridFacade.create_scheduler_facade(record.scheduler_type)
    ssh = shared_ssh_session(record.credentials)
    scheduler.get_log(ssh, record)
  end

  def simulation_manager_install(record)
    # pass - SM already sent
  end

  # -- Monitoring utils --

  def after_monitoring_loop
    close_all_ssh_sessions
  end

  # --

end