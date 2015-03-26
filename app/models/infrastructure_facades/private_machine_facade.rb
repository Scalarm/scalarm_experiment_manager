require_relative 'shell_commands.rb'
require_relative 'shared_ssh'
require_relative 'infrastructure_errors'

class PrivateMachineFacade < InfrastructureFacade
  include ShellCommands
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

    ppn = shared_ssh_session(machine_creds).exec!("cat /proc/cpuinfo | grep MHz | wc -l").strip
    ppn = 'unavailable' if ppn.to_i.to_s != ppn.to_s

    (1..instances_count).map do
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

      record.onsite_monitoring = params.include?(:onsite_monitoring)

      record.initialize_fields
      record.save

      record
    end
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
  def get_credentials(user_id, params)
    PrivateMachineCredentials.where({user_id: user_id}.merge(params))
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
    if params and params.include? 'host' and params.include? 'port'
      cred_query = {}
      cred_query.merge!({host: {'$eq' => params['host'].to_sym}})
      cred_query.merge!({port: {'$eq' => params['port'].to_i}})
      (PrivateMachineCredentials.where(cred_query).map do |cred|
        PrivateMachineRecord.find_all_by_query(query.merge({credentials_id: cred.id}))
      end).flatten
    else
      PrivateMachineRecord.find_all_by_query(query)
    end

  end

  def get_sm_record_by_id(record_id)
    PrivateMachineRecord.find_by_id(record_id.to_s)
  end

  # -- SimulationManager delegation methods --

  def _simulation_manager_stop(record)
    if record.onsite_monitoring
      record.cmd_to_execute_code = "stop"
      record.cmd_to_execute = "kill -9 #{record.pid}"
      record.save
    else
      shared_ssh_session(record.credentials).exec! "kill -9 #{record.pid}"
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
      sm_record.cmd_to_execute = "tail -80 #{sm_record.log_path}"
      sm_record.save

    else
      shared_ssh_session(sm_record.credentials).exec! "tail -80 #{sm_record.log_path}"
    end
  end

  # Nothing to prepare
  def _simulation_manager_prepare_resource(sm_record)
    if sm_record.onsite_monitoring

      sm_record.cmd_to_execute_code = "prepare_resource"
      sm_record.cmd_to_execute = Command::cd_to_simulation_managers(
          ShellBasedInfrastructure.start_simulation_manager_cmd(sm_record)
      )
      sm_record.save

    else
      logger.debug "Sending files and launching SM on host: #{sm_record.credentials.host}:#{sm_record.credentials.ssh_port}"

      InfrastructureFacade.prepare_simulation_manager_package(sm_record.sm_uuid, sm_record.user_id,
                                                                        sm_record.experiment_id, sm_record.start_at) do

        error_counter = 0
        while true
          begin
            ssh = shared_ssh_session(sm_record.credentials)
            break if log_exists?(sm_record, ssh) or send_and_launch_sm(sm_record, ssh)
          rescue Exception => e
            logger.warn "Exception #{e} occured while communication with "\
    "#{sm_record.public_host}:#{sm_record.public_ssh_port} - #{error_counter} tries"
            error_counter += 1
            if error_counter > 10
              sm_record.store_error('install_failed', e.to_s)
              break
            end
          end

          sleep(20)
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
        %x[zip #{LocalAbsolutePath::tmp_sim_code_zip(sm_uuid)} #{code_dir}/*]
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

  end

end
