require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

require_relative 'plgrid/pl_grid_simulation_manager'

require_relative 'infrastructure_facade'
require_relative 'shared_ssh'

require_relative 'infrastructure_errors'

class PlGridFacade < InfrastructureFacade
  include SharedSSH

  attr_reader :ssh_sessions
  attr_reader :long_name
  attr_reader :short_name

  def initialize(scheduler_class)
    @ui_grid_host = 'ui.grid.cyfronet.pl'
    @ssh_sessions = {}
    @scheduler_class = scheduler_class
    @long_name = scheduler.long_name
    @short_name = scheduler.short_name
    super()
  end

  def scheduler
    @scheduler ||= @scheduler_class.new
  end

  def sm_record_class
    PlGridJob
  end

  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    sm_uuid = SecureRandom.uuid

    # prepare locally code of a simulation manager to upload with a configuration file
    InfrastructureFacade.prepare_configuration_for_simulation_manager(sm_uuid, user_id, experiment_id, additional_params['start_at'])

    credentials = GridCredentials.find_by_user_id(user_id)
    raise InfrastructureErrors::NoCredentialsError.new if credentials.nil?
    raise InfrastructureErrors::InvalidCredentialsError.new if credentials.invalid

    if credentials
      # prepare job executable and descriptor
      scheduler.prepare_job_files(sm_uuid)

      #  upload the code to the Grid user interface machine
      begin
        credentials.scp_start do |scp|
          scheduler.send_job_files(sm_uuid, scp)
        end

        credentials.ssh_start do |ssh|
          1.upto(instances_count).each do
            job = create_record(user_id, experiment_id, sm_uuid, additional_params)

            if scheduler.submit_job(ssh, job)
              job.save
            else
              return 'error', I18n.t('plgrid.job_submission.submit_job_failed')
            end
          end
        end
      rescue Net::SSH::AuthenticationFailed => auth_exception
        logger.error "Authentication failed when starting simulation managers for user #{user_id}: #{auth_exception.to_s}"
        return 'error', I18n.t('plgrid.job_submission.authentication_failed', ex: auth_exception)
      rescue Exception => ex
        logger.error "Exception when starting simulation managers for user #{user_id}: #{ex.to_s}\n#{ex.backtrace.join("\n")}"
        return 'error', I18n.t('plgrid.job_submission.error', ex: ex)
      end

      return 'ok', I18n.t('plgrid.job_submission.ok', instances_count: instances_count)
    else
      return 'error', I18n.t('plgrid.job_submission.no_credentials')
    end
  end

  def create_record(user_id, experiment_id, sm_uuid, params)
    job = PlGridJob.new(
        user_id:user_id,
        experiment_id: experiment_id,
        scheduler_type: scheduler.short_name,
        sm_uuid: sm_uuid,
        time_limit: params['time_limit'].to_i
    )

    job.grant_id = params['grant_id'] unless params['grant_id'].blank?
    job.nodes = params['nodes'] unless params['nodes'].blank?
    job.ppn = params['ppn'] unless params['ppn'].blank?

    job.initialize_fields

    job
  end

  def add_credentials(user, params, session)
    credentials = GridCredentials.find_by_user_id(user.id)

    if credentials
      credentials.login = params[:username]
      credentials.password = params[:password]
      credentials.host = params[:host]
    else
      credentials = GridCredentials.new(user_id: user.id, host: params[:host], login: params[:username])
      credentials.password = params[:password]
    end

    credentials.save
    credentials
  end

  def remove_credentials(record_id, user_id, params=nil)
    record = GridCredentials.find_by_id(record_id)
    raise InfrastructureErrors::NoCredentialsError if record.nil?
    raise InfrastructureErrors::AccessDeniedError if record.user_id != user_id
    record.destroy
  end

  def get_sm_records(user_id=nil, experiment_id=nil, params={})
    query = {scheduler_type: scheduler.short_name}
    query.merge!({user_id: user_id}) if user_id
    query.merge!({experiment_id: experiment_id}) if experiment_id
    PlGridJob.find_all_by_query(query)
  end

  def get_sm_record_by_id(record_id)
    PlGridJob.find_by_id(record_id)
  end

  # TODO: decide about usage of count_sm_records
  # def count_sm_records(user_id=nil, experiment_id=nil, attributes=nil)
  #   super(user_id, experiment_id, {scheduler_type: scheduler.short_name}.merge((attributes or {})))
  # end

  def self.retrieve_grants(credentials)
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

  def _simulation_manager_before_monitor(record)
    scheduler.prepare_session(shared_ssh_session(record.credentials))
  end

  def _simulation_manager_stop(record)
    ssh = shared_ssh_session(record.credentials)
    scheduler.cancel(ssh, record)
    scheduler.clean_after_job(ssh, record)
  end

  def _simulation_manager_restart(record)
    ssh = shared_ssh_session(record.credentials)
    scheduler.restart(ssh, record)
  end

  def _simulation_manager_resource_status(record)
    begin
      ssh = shared_ssh_session(record.credentials)
    rescue
      return :error
    end
    scheduler.status(ssh, record)
  end

  def _simulation_manager_running?(record)
    ssh = shared_ssh_session(record.credentials)
    not scheduler.is_done(ssh, record)
  end

  def _simulation_manager_get_log(record)
    ssh = shared_ssh_session(record.credentials)
    scheduler.get_log(ssh, record)
  end

  # Empty implementation: SM was already sent and queued on start_simulation_managers
  # and it should be executed by queuing system.
  def _simulation_manager_install(record)
  end

  def enabled_for_user?(user_id)
    creds = GridCredentials.find_by_query(user_id: user_id)
    creds and not creds.invalid
  end

  # -- Monitoring utils --

  def clean_up_resources
    close_all_ssh_sessions
  end

  # --

  private

  def create_simulation_manager(record)
    PlGridSimulationManager.new(record, self)
  end

end