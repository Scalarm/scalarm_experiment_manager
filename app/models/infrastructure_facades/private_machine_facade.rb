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
                      PrivateMachineCredentials.find_by_query(host: params[:host], user_id: user_id)
                    else
                      PrivateMachineCredentials.find_by_id(params[:credentials_id])
                    end

    raise InfrastructureErrors::NoCredentialsError.new if machine_creds.nil?
    raise InfrastructureErrors::InvalidCredentialsError.new if machine_creds.invalid

    if machine_creds.user_id != user_id
      return 'error', I18n.t('infrastructure_facades.private_machine.no_permissions',
                             name: "#{params['login']}@#{params['host']}", scalarm_login: user.login)
    end

    instances_count.times do
      record = PrivateMachineRecord.new(
          user_id: user_id,
          experiment_id: experiment_id,
          credentials_id: machine_creds.id,
          time_limit: params[:time_limit],
          start_at: params[:start_at],
          sm_uuid: SecureRandom.uuid
      )

      if Rails.application.secrets.include?(:infrastructure_side_monitoring)
        record.infrastructure_side_monitoring = true
      end

      record.initialize_fields
      record.save
    end
    ['ok', I18n.t('infrastructure_facades.private_machine.scheduled_info', count: instances_count,
                        machine_name: machine_creds.machine_desc)]
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
    if record.infrastructure_side_monitoring
      record.cmd_to_execute_code = "stop"
      record.cmd_to_execute = "kill -9 #{record.pid}"
    else
      shared_ssh_session(record.credentials).exec! "kill -9 #{record.pid}"
    end
  end

  def _simulation_manager_restart(record)
    logger.warn "#{record.task_desc} restart invoked, but it is not supported"
  end

  def _simulation_manager_resource_status(record)
    begin
      ssh = shared_ssh_session(record.credentials)
    rescue Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => e
      # remember this error in case of unable to initialize
      record.error_log = e.to_s
      record.save
      return :not_available
    rescue Exception => e
      record.store_error('ssh', e.to_s)
      _simulation_manager_stop(record)
    else
      pid = record.pid
      if pid
        app_running?(ssh, pid) ? :running_sm : :released
      else
        :available
      end
    end
  end

  def _simulation_manager_get_log(record)
    shared_ssh_session(record.credentials).exec! "tail -25 #{record.log_path}"
  end

  # Nothing to prepare
  def _simulation_manager_prepare_resource(record)
    if record.infrastructure_side_monitoring
      record.cmd_to_execute_code = "prepare_resource"
      record.cmd_to_execute = ShellBasedInfrastructure.start_simulation_manager_cmd(record)
      record.save
    else
      logger.debug "Sending files and launching SM on host: #{record.credentials.host}:#{record.credentials.ssh_port}"

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
            break
          end
        end

        sleep(20)
      end
    end
  end

  def _simulation_manager_install(record)
  end

  def enabled_for_user?(user_id)
    true
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

    #scheduler.prepare_job_files(sm_record.sm_uuid, {dest_dir: code_dir}.merge(sm_record.to_h))
    %x[zip /tmp/#{code_dir}.zip #{code_dir}/*]

    Dir.chdir(Rails.root)

    File.join('/', 'tmp', code_dir + ".zip")
  end

end
