require_relative 'shell_commands.rb'
require_relative 'shared_ssh'
require_relative 'infrastructure_errors'

class PrivateMachineFacade < InfrastructureFacade
  include SharedSSH
  include ShellBasedInfrastructure

  attr_reader :ssh_sessions

  # prefix for all created and managed VMs
  VM_NAME_PREFIX = 'scalarm_'

  def initialize
    super()
  end

  # -- InfrastructureFacade implementation --

    def sm_record_class
      PrivateMachineRecord
    end

    # Params hash:
    # - time_limit
    # - start_at
    # - onsite_monitoring [optional] - if is a string 'on' - enable onsite monitoring
    # Alternative - get credentials by ID from database or use simple host matching
    # - 'credentials_id' => id of PrivateMachineCredentials record - this machine will be initialized
    # - 'host' => hostname - matches first PM Credentials with this host name
    def start_simulation_managers(user_id, instances_count, experiment_id, params = {})
      logger.debug "Start simulation managers for experiment #{experiment_id}, additional params: #{params}"

      machine_creds = if params[:host]
                        PrivateMachineCredentials.find_by_query(host: params[:host].to_s, user_id: user_id)
                      else
                        PrivateMachineCredentials.find_by_id(params[:credentials_id].to_s)
                      end

      raise InfrastructureErrors::NoCredentialsError.new if machine_creds.nil?
      raise InfrastructureErrors::InvalidCredentialsError.new if machine_creds.invalid

      if machine_creds.user_id != user_id
        return 'error', I18n.t('infrastructure_facades.private_machine.no_permissions',
                               name: "#{params['login']}@#{params['host']}", scalarm_login: user.login)
      end

      ppn = shared_ssh_session(machine_creds).exec!(get_number_of_cores_command).strip
      ppn = 'unavailable' if ppn.to_i.to_s != ppn.to_s

      onsite_monitoring_enabled = (params[:onsite_monitoring] == 'on')

    records = (1..instances_count).map do
      record = PrivateMachineRecord.new(
          user_id: user_id,
          experiment_id: experiment_id,
          credentials_id: machine_creds.id,
          time_limit: params[:time_limit],
          start_at: params[:start_at],
          sm_uuid: SecureRandom.uuid,
          infrastructure: short_name,
          ppn: ppn
      )

      record.onsite_monitoring = onsite_monitoring_enabled

      record.initialize_fields
      record.save

      record
    end

    if onsite_monitoring_enabled
      sm_uuid = SecureRandom.uuid
      self.class.handle_monitoring_send_errors(records) do
        self.class.send_and_launch_onsite_monitoring(machine_creds, sm_uuid, user_id, short_name, params)
      end
    end

    records
  end

  # See: {InfrastructureFacade#query_simulation_manager_records}
  def query_simulation_manager_records(user_id, experiment_id, params)
    query = {
      user_id: user_id,
      experiment_id: experiment_id,
      infrastructure: short_name
    }

    credentials_id = params[:credentials_id]
    if params.include?(:host)
      creds = PrivateMachineCredentials.find_by_query(host: params[:host].to_s, user_id: user_id)
      credentials_id = creds.id
    end

    query[:credentials_id] = credentials_id unless credentials_id.blank?
    query[:time_limit] = params[:time_limit] unless params[:time_limit].blank?
    query[:start_at] = params[:start_at] unless params[:start_at].blank?
    query[:onsite_monitoring] = (params[:onsite_monitoring] == 'on') unless params[:onsite_monitoring].blank?

    PrivateMachineRecord.where(query)
  end

  def get_number_of_cores_command
    'cat /proc/cpuinfo | grep MHz | wc -l'
  end

  def self.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, infrastructure_name, params={})
    # TODO: implement multiple architectures support
    platform = credentials.runtime_platform

    InfrastructureFacade.prepare_monitoring_config(sm_uuid, user_id,
                                                   [{name: infrastructure_name, credentials_id: credentials.id.to_s}])

    credentials.ssh_session do |ssh|
      # TODO: implement ssh.scp method for gsissh and use here
      credentials.scp_session do |scp|
        SSHAccessedInfrastructure::create_remote_directories(ssh)

        PrivateMachineFacade.remove_remote_monitoring_files(ssh)
        PrivateMachineFacade.upload_monitoring_files(scp, sm_uuid, platform)
        PrivateMachineFacade.remove_local_monitoring_config(sm_uuid)

        cmd = PrivateMachineFacade.start_monitoring_cmd
        Rails.logger.debug("Executing scalarm_monitoring for user #{user_id}: #{cmd}\n#{ssh.exec!(cmd)}")
      end
    end
  end

  def self.remove_remote_monitoring_files(ssh)
    [
        RemoteHomePath::monitoring_config,
        RemoteHomePath::monitoring_package,
        RemoteHomePath::monitoring_binary,
        RemoteHomePath::remote_monitoring_certificate
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
    BashCommand.new.
        cd(RemoteDir::scalarm_root).
        append("unxz -f #{ScalarmFileName::monitoring_package}").
        append("chmod a+x #{ScalarmFileName::monitoring_binary}").
        run_in_background("./#{ScalarmFileName::monitoring_binary} #{ScalarmFileName::monitoring_config}",
                          "#{ScalarmFileName::monitoring_binary}_`date +%Y-%m-%d_%H-%M-%S-$(expr $(date +%N) / 1000000)`.log"
        ).to_s
  end

  def add_credentials(user, params, session)
    credentials = PrivateMachineCredentials.new(
        'user_id'=>user.id,
        'host'=> params[:host],
        'port'=> (params[:port] or 22).to_i,
        'login'=>params[:login]
    )
    credentials.secret_password = params[:secret_password]
    credentials.save
    credentials
  end

  # params - hash of additional query conditions, e.g. {host: 'localhost'}
  # returns: array of PrivateMachineCredentials
  def get_credentials(user_id, params)
    query = {user_id: user_id}.merge(params)
    PrivateMachineCredentials.where(query).to_a
  end

  def remove_credentials(record_id, user_id, type)
    record = PrivateMachineCredentials.find_by_id(record_id.to_s)
    raise InfrastructureErrors::NoCredentialsError if record.nil?
    raise InfrastructureErrors::AccessDeniedError if record.user_id != user_id
    record.destroy
  end

  def long_name
    'Private resources'
  end

  def short_name
    'private_machine'
  end

  def _get_sm_records(query, params={})
    if params and params.include? 'credentials_id'
      query.merge!({credentials_id: BSON::ObjectId(params['credentials_id'].to_s)})
    end
    PrivateMachineRecord.find_all_by_query(query)
  end

  def get_sm_record_by_id(record_id)
    PrivateMachineRecord.find_by_id(record_id.to_s)
  end

  ##
  # Returns list of hashes representing distinct configurations of infrastructure
  # Subinfrastructures are distinguished by:
  #  * private machine credentials
  def get_resource_configurations(user_id)
    PrivateMachineCredentials.where(user_id: user_id).map do |credentials|
      {name: short_name.to_sym, params: {credentials_id: credentials.id.to_s}}
    end
  end

  # -- SimulationManager delegation methods --

  def _simulation_manager_stop(record)
    if record.onsite_monitoring
      record.cmd_to_execute_code = "stop"
      record.cmd_to_execute = "kill -9 #{record.pid} || true"
      record.cmd_delegated_at = Time.now
      record.save
    else
      shared_ssh_session(record.credentials).exec! "kill -9 #{record.pid} || true"
    end
  end

  def _simulation_manager_restart(record)
    logger.warn "#{record.task_desc} restart invoked, but it is not supported"
  end

  def _simulation_manager_resource_status(sm_record)
    begin
      ssh = shared_ssh_session(sm_record.credentials)
    rescue Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => e
      # remember this error in case of unable to initialize
      sm_record.error_log = e.to_s
      sm_record.save
      return :not_available
    rescue Exception => e
      sm_record.store_error('ssh', e.to_s)
      _simulation_manager_stop(sm_record)
    else
      pid = sm_record.pid
      if pid
        app_running?(ssh, pid) ? :running_sm : :released
      else
        :available
      end
    end
  end

  def _simulation_manager_get_log(sm_record)
    if sm_record.onsite_monitoring

      sm_record.cmd_to_execute_code = "get_log"
      sm_record.cmd_to_execute = BashCommand.new.tail(sm_record.absolute_log_path, 80).to_s
      sm_record.cmd_delegated_at = Time.now
      sm_record.save
      nil

    else
      shared_ssh_session(sm_record.credentials).exec! BashCommand.new.tail(sm_record.absolute_log_path, 80).to_s
    end
  end

  def self.sim_installation_retry_count
    5
  end

  def self.sim_installation_retry_delay
    5
  end

  # Nothing to prepare
  def _simulation_manager_prepare_resource(sm_record)
    if sm_record.onsite_monitoring

      sm_record.cmd_to_execute_code = "prepare_resource"
      sm_record.cmd_to_execute = ShellBasedInfrastructure.start_simulation_manager_cmd(sm_record).to_s
      sm_record.cmd_delegated_at = Time.now
      sm_record.save

    else
      platform = sm_record.credentials.runtime_platform

      logger.debug "Sending files and launching SM on host (#{platform}): #{sm_record.credentials.host}:#{sm_record.credentials.ssh_port}"

      InfrastructureFacade.prepare_simulation_manager_package(sm_record.sm_uuid, sm_record.user_id,
                                                                        sm_record.experiment_id, sm_record.start_at,
                                                                        platform) do

        error_counter = 0
        ssh = nil

        # trying to connect via SSH multiple times
        while true
          begin
            ssh = shared_ssh_session(sm_record.credentials)
            break
          rescue StandardError => e
            logger.warn "Exception #{e} occured while communication with "\
    "#{sm_record.public_host}:#{sm_record.public_ssh_port} - #{error_counter} tries"
            error_counter += 1
            if error_counter >= self.class.sim_installation_retry_count
              sm_record.store_error('install_failed', e.to_s)
              raise
            end
          end

          sleep(self.class.sim_installation_retry_delay)
        end

        if log_exists?(sm_record, ssh)
          logger.warn("Log file for #{sm_record.id} already exists - not sending SiM")
        else
          pid = send_and_launch_sm(sm_record, ssh)
          if pid.blank?
            logger.error("PID is blank after SiM (#{sm_record.id}) send and launch - it may be caused by not-supported shell")
            sm_record.store_error('install_failed', 'Cannot get PID')
          else
            return pid
          end
        end
      end
    end
  end

  def _simulation_manager_install(record)
  end

  def enabled_for_user?(user_id)
    PrivateMachineCredentials.where(user_id: user_id).count > 0
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
      FileUtils.remove_dir(code_dir, true)
    end

  end

end
