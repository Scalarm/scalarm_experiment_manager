require 'securerandom'
require 'fileutils'
require 'net/ssh'
require 'net/scp_ext'
require 'scalarm/service_core/grid_proxy'

require_relative 'plgrid/pl_grid_simulation_manager'

require_relative 'infrastructure_facade'
require_relative 'shared_ssh'

require_relative 'infrastructure_errors'

class PlGridFacade < InfrastructureFacade
  include SSHAccessedInfrastructure
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

  # additional_params:
  # - (:plgrid_login and :plgrid_password) or :proxy
  # -
  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    # 1. checking if the user can schedule SiM
    credentials = if PlGridFacade.using_temp_credentials?(additional_params)
                    PlGridFacade.create_temp_credentials(additional_params)
                  else
                    PlGridFacade.get_credentials_from_db(user_id)
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

      # 2.c create record for SiM and save it
      record = create_record(user_id, experiment_id, sm_uuid, additional_params)
      record.save

      record
    end

    if additional_params[:onsite_monitoring]
      sm_uuid = SecureRandom.uuid
      self.class.handle_monitoring_send_errors(records) do
        self.class.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, scheduler.short_name, additional_params)
      end
    end

    records
  end

  # See: {InfrastructureFacade#query_simulation_manager_records}
  def query_simulation_manager_records(user_id, experiment_id, params)
    query = {
      user_id: user_id,
      experiment_id: experiment_id,
      scheduler_type: scheduler.short_name
    }
    query[:grant_identifier] = params['grant_identifier'] unless params['grant_identifier'].blank?
    query[:nodes] = params['nodes'] unless params['nodes'].blank?
    query[:ppn] = params['ppn'] unless params['ppn'].blank?
    query[:plgrid_host] = params['plgrid_host'] unless params['plgrid_host'].blank?
    query[:queue_name] = params['queue'] unless params['queue'].blank?
    query[:onsite_monitoring] = if params['onsite_monitoring'].blank? then false else true end
    query[:time_limit] = params['time_limit'].to_i unless params['time_limit'].blank?
    query[:start_at] = params['start_at'] unless params['start_at'].blank?

    PlGridJob.where(query)
  end

  def create_records(count, *args)
    (1..count).map do
      record = create_record(*args)
      record.save
      record
    end
  end

  def self.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, scheduler_name, params={})
    # TODO: implement multiple architectures support
    arch = 'linux_amd64'

    InfrastructureFacade.prepare_monitoring_config(sm_uuid, user_id, [{name: scheduler_name}])

    credentials.ssh_session do |ssh|
      # TODO: implement ssh.scp method for gsissh and use here
      credentials.scp_session do |scp|
        PlGridFacade.remove_remote_monitoring_files(ssh)

        SSHAccessedInfrastructure::create_remote_directories(ssh)
        key_passphrase = params[:key_passphrase]
        PlGridFacade.generate_proxy(ssh, key_passphrase) if not credentials.secret_proxy and key_passphrase
        PlGridFacade.clone_proxy(ssh, RemoteAbsolutePath::remote_monitoring_proxy)
        PlGridFacade.upload_monitoring_files(scp, sm_uuid, arch)
        PlGridFacade.remove_local_monitoring_config(sm_uuid)

        cmd = PlGridFacade.start_monitoring_cmd
        Rails.logger.debug("Executing scalarm_monitoring for user #{user_id}: #{cmd}\n#{ssh.exec!(cmd)}")
      end
    end
  end

  def self.remove_remote_monitoring_files(ssh)
    [
        RemoteHomePath::monitoring_config,
        RemoteHomePath::monitoring_package,
        RemoteHomePath::monitoring_binary,
        RemoteHomePath::remote_monitoring_certificate,
        RemoteAbsolutePath::remote_monitoring_proxy
    ].each do |path|
      ssh.exec! BashCommand.new.rm(path, true).to_s
    end
  end

  # TODO: can be moved to base class or util class
  def self.upload_monitoring_files(scp, sm_uuid, arch)
    local_config = LocalAbsolutePath::tmp_monitoring_config(sm_uuid)
    local_package = LocalAbsolutePath::monitoring_package(arch)
    scp.upload_multiple! [local_config, local_package], RemoteDir::scalarm_root

    if LocalAbsolutePath::certificate
      scp.upload! LocalAbsolutePath::certificate, RemoteHomePath::remote_monitoring_certificate
    end
  end

  # TODO: can be moved to base class or util class
  def self.remove_local_monitoring_config(sm_uuid)
    FileUtils.rm_rf(LocalAbsoluteDir::tmp_monitoring_package(sm_uuid))
  end

  def self.start_monitoring_cmd
    BashCommand.new.cd(RemoteDir::scalarm_root).
        append("unxz -f #{ScalarmFileName::monitoring_package}").
        append("chmod a+x #{ScalarmFileName::monitoring_binary}").
        append("export X509_USER_PROXY=#{ScalarmFileName::remote_proxy}").
        run_in_background("./#{ScalarmFileName::monitoring_binary} #{ScalarmFileName::monitoring_config}",
          "#{ScalarmFileName::monitoring_binary}_`date +%Y-%m-%d_%H-%M-%S-$(expr $(date +%N) / 1000000)`.log").to_s
  end

  def self.clone_proxy(ssh, remote_path)
    # TODO: checking if proxy file exists?
    ssh.exec! BashCommand.new.append("cp `voms-proxy-info -p` #{remote_path}").to_s
  end

  # TODO: NOTE: without voms extension!
  def self.generate_proxy(ssh, key_passphrase)
    output = ''
    Timeout::timeout 30 do
      output = ssh.exec! BashCommand.new.append("echo #{key_passphrase} | grid-proxy-init -rfc -hours 24").to_s
    end
    Rails.logger.debug("grid-proxy-init output: #{output}")
    output
  end

  def self.using_temp_credentials?(params)
    params.include?(:plgrid_login) or params.include?(:proxy)
  end

  # Params is a Hash, it should contain :
  # - login:
  def self.create_temp_credentials(params)
    # if proxy provided, use user name from proxy
    login = ((params[:proxy] and Scalarm::ServiceCore::GridProxy::Proxy.new(params[:proxy]).username) or
        params[:plgrid_login])
    raise StandardError.new('Neither plgrid_login nor proxy provided to create temporary credentials') unless login

    creds = GridCredentials.new({login: login})

    creds.password = params[:plgrid_password] if params.include? :plgrid_password
    creds.secret_proxy = params[:proxy] if params.include? :proxy
    creds
  end

  def self.get_credentials_from_db(user_id)
    GridCredentials.find_by_user_id(user_id)
  end

  # params: (string keys)
  # - time_limit
  # - start_at
  # - grant_id (optional)
  # - nodes (optional)
  # - ppn (optional)
  # - plgrid_host (optional)
  # - queue (optional)
  # - onsite_monitoring (optional) - monitoring will be enabled if onsite_monitoring is not blank
  def create_record(user_id, experiment_id, sm_uuid, params)
    job = PlGridJob.new(
        user_id:user_id,
        experiment_id: experiment_id,
        scheduler_type: scheduler.short_name,
        sm_uuid: sm_uuid,
        time_limit: params['time_limit'].to_i,
        infrastructure: short_name,
    )

    job.start_at = params['start_at']
    job.grant_identifier = params['grant_identifier'] unless params['grant_identifier'].blank?
    job.nodes = params['nodes'] unless params['nodes'].blank?
    job.ppn = params['ppn'] unless params['ppn'].blank?
    job.plgrid_host = params['plgrid_host'] unless params['plgrid_host'].blank?
    job.queue_name = params['queue'] unless params['queue'].blank?
    job.memory = params['memory'].to_i unless params['memory'].blank?

    job.initialize_fields

    job.onsite_monitoring = if params['onsite_monitoring'].blank? then false else true end

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

  def _get_sm_records(query, params={})
    query.merge!({scheduler_type: scheduler.short_name})
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
        grant_output = ssh.exec!(BashCommand.new.append('plg-show-grants').to_s).split("\n").select{|line| line.start_with?('|')}
      end

      grant_output.each do |line|
        grant_identifier = line.split('|')[1].strip
        grants << grant_identifier.split('(*)').first.strip unless grant_identifier.include?('GrantID')
      end
    rescue => e
      Rails.logger.error("Could not read user's grants - #{e}")
    end

    grants
  end

  ##
  # Returns list of hashes representing distinct resource configurations
  # Delegates method to classes inheriting from #PlGridSchedulerBase
  # @param user_id [BSON::ObjectId, String]
  # @return [Array<Hash>] list of resource configurations
  def get_resource_configurations(user_id)
    scheduler.get_resource_configurations(user_id)
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
    if sm_record.onsite_monitoring
      if sm_record.cmd_to_execute_code.blank?
        sm_record.cmd_to_execute_code = "stop"
        sm_record.cmd_to_execute = BashCommand.new.
                                      append(scheduler.cancel_sm_cmd(sm_record)).
                                      append(scheduler.clean_after_sm_cmd(sm_record)).to_s
        sm_record.cmd_delegated_at = Time.now
        sm_record.save
      end

    else
      ssh = shared_ssh_session(sm_record.credentials)
      scheduler.cancel(ssh, sm_record)
      scheduler.clean_after_job(ssh, sm_record)
    end
  end

  def _simulation_manager_restart(sm_record)
    if sm_record.onsite_monitoring
      sm_record.cmd_to_execute_code = 'restart'
      sm_record.cmd_to_execute = scheduler.restart_sm_cmd(sm_record)
      sm_record.cmd_delegated_at = Time.now
      sm_record.save
    else
      ssh = shared_ssh_session(sm_record.credentials)
      scheduler.restart(ssh, sm_record)
    end
  end

  def _simulation_manager_resource_status(sm_record)
    if sm_record.onsite_monitoring
      sm_record.resource_status || :not_available
    else

      ssh = nil

      begin
        ssh = shared_ssh_session(sm_record.credentials)
      rescue Gsi::ProxyError
        raise
      rescue => e
        # remember this error in case of unable to initialize
        sm_record.error_log = e.to_s
        sm_record.save
        return :not_available
      end

      begin
        job_id = sm_record.job_identifier
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
      rescue => e
        logger.error "Error occurred when checking resource status: #{e}"
        :error
      end
    end
  end

  def _simulation_manager_get_log(sm_record)
    if sm_record.onsite_monitoring

      sm_record.cmd_to_execute_code = "get_log"
      sm_record.cmd_to_execute = scheduler.get_log_cmd(sm_record).to_s
      sm_record.cmd_delegated_at = Time.now
      sm_record.save

      nil
    else

      ssh = shared_ssh_session(sm_record.credentials)
      scheduler.get_log(ssh, sm_record)

    end
  end

  def _simulation_manager_prepare_resource(sm_record)
    if sm_record.onsite_monitoring

      sm_record.cmd_to_execute_code = "prepare_resource"
      sm_record.cmd_to_execute = scheduler.submit_job_cmd(sm_record).to_s
      sm_record.cmd_delegated_at = Time.now
      sm_record.save

    else
      sm_record.validate

      #  upload the code to the Grid user interface machine
      begin
        ssh = shared_ssh_session(sm_record.credentials)
        create_and_upload_simulation_manager(ssh, sm_record)

        begin
          sm_record.job_identifier = scheduler.submit_job(ssh, sm_record)
          sm_record.save
        rescue JobSubmissionFailed => job_failed
          logger.warn "Scheduling job failed: #{job_failed.to_s}"
          sm_record.store_error('install_failed', job_failed.to_s)
        end

      rescue Net::SSH::AuthenticationFailed => auth_exception
        logger.error "Authentication failed when starting simulation managers for user #{sm_record.user_id}: #{auth_exception.to_s}"
        sm_record.store_error('ssh')
      rescue => ex
        logger.error "Exception when starting simulation managers for user #{sm_record.user_id}: #{ex.to_s}\n#{ex.backtrace.join("\n")}"
        sm_record.store_error('install_failed', "#{ex.to_s}\n#{ex.backtrace.join("\n")}")
      end

    end
  end

  def create_and_upload_simulation_manager(ssh, sm_record)
    sm_uuid = sm_record.sm_uuid
    SSHAccessedInfrastructure::create_remote_directories(ssh)

    InfrastructureFacade.prepare_simulation_manager_package(sm_uuid, sm_record.user_id, sm_record.experiment_id, sm_record.start_at) do
      scheduler.create_tmp_job_files(sm_uuid, sm_record.to_h) do
        ssh.scp do |scp|
          scheduler.send_job_files(sm_uuid, scp)
        end
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
    !!(creds and (creds.secret_proxy or (creds.password and not creds.invalid)))
  end

  def force_onsite_monitoring?(user_id)
    scheduler.onsite_monitorable? and not valid_credentials_available?(user_id)
  end

  def other_params_for_booster(user_id, request_params={})
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
    sm_uuid = sm_record.sm_uuid

    Rails.logger.debug "Preparing Simulation Manager package with id: #{sm_uuid}"

    InfrastructureFacade.prepare_simulation_manager_package(sm_uuid, nil, sm_record.experiment_id, sm_record.start_at) do
      code_dir = LocalAbsoluteDir::tmp_sim_code(sm_uuid)
      FileUtils.remove_dir(code_dir, true)
      FileUtils.mkdir(code_dir)
      scheduler.create_tmp_job_files(sm_uuid, {dest_dir: code_dir, sm_record: sm_record.to_h}) do


        FileUtils.mv(LocalAbsolutePath::tmp_sim_zip(sm_uuid), code_dir)

        Dir.chdir(LocalAbsoluteDir::tmp) do
          %x[zip #{LocalAbsolutePath::tmp_sim_code_zip(sm_uuid)} #{ScalarmDirName::tmp_sim_code(sm_uuid)}/*]
        end
        FileUtils.rm_rf(LocalAbsoluteDir::tmp_sim_code(sm_uuid))

        zip_path = LocalAbsolutePath::tmp_sim_code_zip(sm_uuid)

        if block_given?
          begin
            yield zip_path
          ensure
            FileUtils.rm_rf(zip_path)
          end
        else
          return zip_path
        end
      end
      FileUtils.remove_dir(code_dir, true)
    end

  end

  def destroy_unused_credentials(authentication_mode, user)
  	if authentication_mode == :x509_proxy
      user_sessions = UserSession.where(session_id: user.id)
      return unless user_sessions.select(&:valid?).empty?

  		monitored_jobs = PlGridJob.where(user_id: user.id, scheduler_type: {'$in' => ['qsub', 'qcg']},
  										 state: {'$ne' => :error}, onsite_monitoring: {'$ne' => true})
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
