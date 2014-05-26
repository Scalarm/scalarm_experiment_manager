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
  # - 'credentials_id' => id of PrivateMachineCredentials record - this machine will be initialized
  def start_simulation_managers(user_id, instances_count, experiment_id, params = {})
    logger.debug "Start simulation managers for experiment #{experiment_id}, additional params: #{params}"

    machine_creds = PrivateMachineCredentials.find_by_id(params[:credentials_id])
    raise InfrastructureErrors::NoCredentialsError.new if machine_creds.nil?
    raise InfrastructureErrors::InvalidCredentialsError.new if machine_creds.invalid

    # TODO: checking for nil deprecated
    if machine_creds.nil?
      return 'error', I18n.t('infrastructure_facades.private_machine.unknown_machine_id')
    elsif machine_creds.user_id != user_id
      return 'error', I18n.t('infrastructure_facades.private_machine.no_permissions',
                             name: "#{params['login']}@#{params['host']}", scalarm_login: user.login)
    end

    instances_count.times do
      record = PrivateMachineRecord.new(
          user_id: user_id,
          experiment_id: experiment_id,
          credentials_id: params[:credentials_id],
          time_limit: params[:time_limit],
          start_at: params[:start_at],
          sm_uuid: SecureRandom.uuid
      )
      record.initialize_fields
      record.save
    end
    ['ok', I18n.t('infrastructure_facades.private_machine.scheduled_info', count: instances_count,
                        machine_name: machine_creds.machine_desc)]
  end

  def add_credentials(user, params, session)
    credentials = PrivateMachineCredentials.new(
        'user_id'=>user.id,
        'host'=>params[:host],
        'port'=>params[:port].to_i,
        'login'=>params[:login]
    )
    credentials.secret_password = params[:secret_password]
    credentials.save
    credentials
  end

  def remove_credentials(record_id, user_id, type)
    record = PrivateMachineCredentials.find_by_id(record_id)
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

  def get_sm_records(user_id=nil, experiment_id=nil, params={})
    query = (user_id ? {user_id: user_id} : {})
    query.merge!({experiment_id: experiment_id}) if experiment_id
    PrivateMachineRecord.find_all_by_query(query)
  end

  def get_sm_record_by_id(record_id)
    PrivateMachineRecord.find_by_id(record_id)
  end

  # -- SimulationManager delegation methods --

  def _simulation_manager_stop(record)
    shared_ssh_session(record.credentials).exec! "kill -9 #{record.pid}"
  end

  def _simulation_manager_restart(record)
    logger.warn "#{record.task_desc} restart invoked, but it is not supported"
  end

  def _simulation_manager_resource_status(record)
    begin
      shared_ssh_session(record.credentials)
      :running
    rescue Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => e
      # remember this error in case of unable to initialize
      record.error_log = e.to_s
      record.save
      :initializing
    rescue Exception => e
      record.store_error('ssh', e.to_s)
      _simulation_manager_stop(record)
    end
  end

  def _simulation_manager_running?(record)
    not shared_ssh_session(record.credentials).exec!("ps #{record.pid} | tail -n +2").blank?
  end

  def _simulation_manager_get_log(record)
    shared_ssh_session(record.credentials).exec! "tail -25 #{record.log_path}"
  end

  def _simulation_manager_install(record)
    logger.debug "Installing SM on host #{record.credentials.host}:#{record.credentials.ssh_port}"

    InfrastructureFacade.prepare_configuration_for_simulation_manager(record.sm_uuid, record.user_id,
                                                                      record.experiment_id, record.start_at)

    error_counter = 0
    while true
      begin
        ssh = shared_ssh_session(record.credentials)
        break if log_exists?(record, ssh) or send_and_launch_sm(record, ssh)
      rescue Exception => e
        logger.warn "Exception #{e} occured while communication with "\
"#{record.public_host}:#{record.public_ssh_port} - #{error_counter} tries"
        error_counter += 1
        if error_counter > 10
          record.store_error('install_failed', e.to_s)
        end
      end

      sleep(20)
    end
  end

  # -- Monitoring utils --

  def clean_up_resources
    close_all_ssh_sessions
  end

  # --

end
