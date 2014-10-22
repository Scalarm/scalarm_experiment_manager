require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp_ext'

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
    @scheduler_class = scheduler_class
    @long_name = scheduler_class.long_name
    @short_name = scheduler_class.short_name
    @ui_grid_host = 'zeus.cyfronet.pl'
    @ssh_sessions = {}
    super()
  end

  def scheduler
    @scheduler ||= @scheduler_class.new(logger)
  end

  def sm_record_class
    PlGridJob
  end

  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    # 1. checking if the user can schedule SiM
    credentials = if using_temp_credentials?(additional_params)
                    create_temp_credentials(additional_params)
                  else
                    get_credentials_from_db(user_id)
                  end

    if credentials.nil?
      raise InfrastructureErrors::NoCredentialsError.new
    end

    if credentials.invalid or (credentials.password.blank? and credentials.secret_proxy.blank?)
      raise InfrastructureErrors::InvalidCredentialsError.new
    end

    # 2. create instances_count SiMs
    records = (1..instances_count).map do
      # 2.a create temp pass for SiM
      sm_uuid = SecureRandom.uuid
      if SimulationManagerTempPassword.find_by_sm_uuid(sm_uuid).nil?
        SimulationManagerTempPassword.create_new_password_for(sm_uuid, experiment_id)
      end
      # 2.b prepare SiM package unless SiM is monitored on-site
      unless additional_params[:onsite_monitoring]
        InfrastructureFacade.prepare_configuration_for_simulation_manager(sm_uuid, user_id, experiment_id, additional_params['start_at'])
      end
      # 2.c create record for SiM and save it
      record = create_record(user_id, experiment_id, sm_uuid, additional_params)
      record.save

      record
    end

    send_and_launch_onsite_monitoring(credentials, user_id, additional_params) if additional_params[:onsite_monitoring]

    records
  end

  def create_records(count, *args)
    (1..count).map do
      record = create_record(*args)
      record.save
      record
    end
  end

  def send_and_launch_onsite_monitoring(credentials, user_id, params)
    sm_uuid = SecureRandom.uuid

    InfrastructureFacade.prepare_monitoring_package(sm_uuid, user_id, scheduler.short_name)
    bin_base_name = 'scalarm_monitoring_linux_x86_64'

    remote_proxy_path = '~/.scalarm_proxy'
    key_passphrase = params[:key_passphrase]
    credentials.generate_proxy(key_passphrase) if not credentials.secret_proxy and key_passphrase
    credentials.clone_proxy(remote_proxy_path)

    credentials.ssh_session do |ssh|
      ssh.exec! 'rm -f config.json' # TODO: change name!
      ssh.exec! "rm -f #{bin_base_name}.xz"
      ssh.exec! "rm -f #{bin_base_name}"
    end

    credentials.scp_session do |scp|
      scp.upload_multiple! [
                               File.join('/tmp', InfrastructureFacade.monitoring_package_dir(sm_uuid), 'config.json'),
                               File.join(Rails.root, 'public', 'scalarm_monitoring', "#{bin_base_name}.xz")
                           ], '.'
    end

    credentials.ssh_session do |ssh|
      ssh.exec! "mv #{bin_base_name} #{}"
    end

    if Rails.application.secrets.certificate_path
      credentials.ssh_session do |ssh|
        ssh.exec! 'rm -f ~/.scalarm_certificate'
      end

      credentials.scp_session do |scp|
        scp.upload! Rails.application.secrets.certificate_path, '~/.scalarm_certificate'
      end
    end

    credentials.ssh_session do |ssh|
      cmd = ShellCommands.chain(
          "unxz -f #{bin_base_name}.xz",
          "chmod a+x #{bin_base_name}",
          "X509_USER_PROXY=#{remote_proxy_path} #{ShellCommands.
              run_in_background("./#{bin_base_name}", "#{bin_base_name}-`date +%H-%M_%d-%m-%y`.log")}"
      )
      Rails.logger.debug("Executing scalarm_monitoring: #{ssh.exec!(cmd)}")
    end
  end

  def using_temp_credentials?(params)
    params.include?(:plgrid_login)
  end

  def create_temp_credentials(params)
    creds = GridCredentials.new({login: params[:plgrid_login]})
    creds.password = params[:plgrid_password]
    creds
  end

  def get_credentials_from_db(user_id)
    GridCredentials.find_by_user_id(user_id)
  end

  def create_record(user_id, experiment_id, sm_uuid, params)
    job = PlGridJob.new(
        user_id:user_id,
        experiment_id: experiment_id,
        scheduler_type: scheduler.short_name,
        sm_uuid: sm_uuid,
        time_limit: params['time_limit'].to_i,
        infrastructure: short_name
    )

    job.grant_id = params['grant_id'] unless params['grant_id'].blank?
    job.nodes = params['nodes'] unless params['nodes'].blank?
    job.ppn = params['ppn'] unless params['ppn'].blank?
    job.plgrid_host = params['plgrid_host'] unless params['plgrid_host'].blank?
    job.queue_name = params['queue'] unless params['queue'].blank?

    job.initialize_fields

    job.infrastructure_side_monitoring = params.include?(:onsite_monitoring)

    job
  end

  def add_credentials(user, params, session)
    credentials = GridCredentials.find_by_user_id(user.id)

    if credentials
      credentials.login = params[:username]
      credentials.password = params[:password]
      credentials.host = params[:host]
      credentials.secret_proxy = nil
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

  def self.retrieve_grants(credentials)
    return [] if credentials.nil?

    grants, grant_output = [], []

    begin
      credentials.ssh_session do |ssh|
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
  
  # Appends PL-Grid scheduler name to shared SSH session ID
  # NOTICE: not used because of stateless SSH sessions
  #def shared_ssh_session(record)
  #  super(record, @short_name)
  #end

  # -- SimulationManager delegation methods --

  def _simulation_manager_before_monitor(record)
    record.validate
    # Not needed now
    # scheduler.prepare_session(shared_ssh_session(record.credentials))
  end

  def validate_credentials_for(record)
    record.validate_credentials
  end

  def _simulation_manager_stop(sm_record)
    if sm_record.infrastructure_side_monitoring
      if sm_record.cmd_to_execute_code.blank?
        sm_record.cmd_to_execute_code = "stop"
        sm_record.cmd_to_execute = [ scheduler.cancel_sm_cmd(sm_record),
                                     scheduler.clean_after_sm_cmd(sm_record) ].join(';')
      end

    else
      ssh = shared_ssh_session(sm_record.credentials)
      scheduler.cancel(ssh, sm_record)
      scheduler.clean_after_job(ssh, sm_record)
    end
  end

  def _simulation_manager_restart(sm_record)
    if sm_record.infrastructure_side_monitoring
      sm_record.cmd_to_execute = scheduler.restart_sm_cmd(sm_record)
    else
      ssh = shared_ssh_session(sm_record.credentials)
      scheduler.restart(ssh, sm_record)
    end
  end

  def _simulation_manager_resource_status(sm_record)
    ssh = nil

    begin
      ssh = shared_ssh_session(sm_record.credentials)
    rescue Gsi::ProxyError
      raise
    rescue Exception => e
      # remember this error in case of unable to initialize
      sm_record.error_log = e.to_s
      sm_record.save
      return :not_available
    end

    begin
      job_id = sm_record.job_id
      if job_id
        status = scheduler.status(ssh, sm_record)
        case status
          when :initializing then
            :initializing
          when :running then
            :running_sm
          when :deactivated then
            :released
          when :error then
            :error
          else
            logger.warn "Unknown state from PL-Grid scheduler: #{status}"
            :error
        end
      else
        :available
      end
    rescue Exception
      :error
    end
  end

  def _simulation_manager_get_log(sm_record)
    if sm_record.infrastructure_side_monitoring

      sm_record.cmd_to_execute_code = "get_log"
      sm_record.cmd_to_execute = scheduler.get_log_cmd(sm_record)
      sm_record.save

      nil
    else

      ssh = shared_ssh_session(sm_record.credentials)
      scheduler.get_log(ssh, sm_record)

    end
  end

  def _simulation_manager_prepare_resource(sm_record)
    if sm_record.infrastructure_side_monitoring

      sm_record.cmd_to_execute_code = "prepare_resource"
      sm_record.cmd_to_execute = scheduler.submit_job_cmd(sm_record)
      sm_record.save

    else

      sm_uuid = sm_record.sm_uuid

      sm_record.validate

      scheduler.prepare_job_files(sm_uuid, sm_record.to_h)

      #  upload the code to the Grid user interface machine
      begin
        sm_record.credentials.scp_session do |scp|
          scheduler.send_job_files(sm_uuid, scp)
        end

        ssh = shared_ssh_session(sm_record.credentials)
        if scheduler.submit_job(ssh, sm_record)
          sm_record.save
        else
          logger.warn 'Scheduling job failed!'
          sm_record.store_error('install_failed') # TODO: get output from .submit_job and save as error_log
        end
      rescue Net::SSH::AuthenticationFailed => auth_exception
        logger.error "Authentication failed when starting simulation managers for user #{user_id}: #{auth_exception.to_s}"
        sm_record.store_error('ssh')
      rescue Exception => ex
        logger.error "Exception when starting simulation managers for user #{sm_record.user_id}: #{ex.to_s}\n#{ex.backtrace.join("\n")}"
        sm_record.store_error('install_failed', "#{ex.to_s}\n#{ex.backtrace.join("\n")}")
      end

    end
  end

  # Empty implementation: SM was already sent and queued on start_simulation_managers
  # and it should be executed by queuing system.
  def _simulation_manager_install(record)
  end

  def enabled_for_user?(user_id)
    scheduler.onsite_monitorable? or valid_credentials_available?(user_id)
  end

  def valid_credentials_available?(user_id)
    creds = GridCredentials.find_by_user_id user_id
    !!(creds and (creds.secret_proxy or not creds.invalid))
  end

  def force_onsite_monitoring?(user_id)
    scheduler.onsite_monitorable? and not valid_credentials_available?(user_id)
  end

  def other_params_for_booster(user_id)
    {
        force_onsite_monitoring: force_onsite_monitoring?(user_id)
    }
  end

  # -- Monitoring utils --

  def clean_up_resources
    close_all_ssh_sessions
  end

  # --

  def simulation_manager_code(sm_record)
    Rails.logger.debug "Preparing Simulation Manager package with id: #{sm_record.sm_uuid}"

    InfrastructureFacade.prepare_configuration_for_simulation_manager(sm_record.sm_uuid, nil, sm_record.experiment_id, sm_record.start_at)

    code_dir = "scalarm_simulation_manager_code_#{sm_record.sm_uuid}"

    Dir.chdir('/tmp')
    FileUtils.remove_dir(code_dir, true)
    FileUtils.mkdir(code_dir)
    FileUtils.mv("scalarm_simulation_manager_#{sm_record.sm_uuid}.zip", code_dir)

    scheduler.prepare_job_files(sm_record.sm_uuid, {dest_dir: code_dir, sm_record: sm_record.to_h})

    %x[zip /tmp/#{code_dir}.zip #{code_dir}/*]

    Dir.chdir(Rails.root)

    File.join('/', 'tmp', code_dir + ".zip")
  end

  def destroy_unused_credentials(authentication_mode, user)
  	if authentication_mode == :x509_proxy
  		if UserSession.where(session_id: user.id).size > 0
  			return
  		end

  		monitored_jobs = PlGridJob.where(user_id: user.id, scheduler_type: {'$in' => ['qsub', 'qcg']},
  										 state: {'$ne' => :error}, infrastructure_side_monitoring: {'$ne' => true})
  		if monitored_jobs.size > 0
  			return
  		end

  		gc = GridCredentials.where(user_id: user.id).first
      unless gc.nil?
  			gc._delete_attribute(:secret_proxy)

        if gc.password.nil?
          gc.destroy
        else
          gc.save
        end
  		end
  	end
  end

  private

  def create_simulation_manager(record)
    PlGridSimulationManager.new(record, self)
  end

end