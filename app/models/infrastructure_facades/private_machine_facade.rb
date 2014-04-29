require_relative 'private_machines/private_machine_simulation_manager.rb'
require_relative 'shell_commands.rb'
require_relative 'shared_ssh'

class PrivateMachineFacade < InfrastructureFacade
  include ShellCommands
  include SharedSSH

  attr_reader :ssh_sessions

  # prefix for all created and managed VMs
  VM_NAME_PREFIX = 'scalarm_'

  def initialize
    super()
  end

  # -- InfrastructureFacade implementation --

  def current_state(user)
    I18n.t('infrastructure_facades.private_machine.current_state', tasks: count_scheduled_tasks(user.id))
  end

  # TODO: group by PrivateMachineRecord.credentials_id

  # def monitoring_loop
  #   machine_records = PrivateMachineRecord.all.group_by {|r| r.credentials_id}
  #   machine_threads = []
  #   machine_records.each do |creds_id, records|
  #     credentials = PrivateMachineCredentials.find_by_id(creds_id)
  #     if credentials.nil?
  #       logger.error "Credentials missing: #{creds_id}, affected records: #{records.map &:id}"
  #       records.map {|r| check_record_expiration(r)}
  #       next
  #     end
  #     machine_threads << Thread.start { monitor_machine_records(credentials, records) }
  #   end
  #   machine_threads.map &:join
  # end
  #
  # def monitor_machine_records(credentials, records)
  #   logger.debug "Monitoring private resources on: #{credentials.machine_desc} (#{records.count} tasks)"
  #   begin
  #     credentials.ssh_start do |ssh|
  #       records.each do |r|
  #         begin
  #           # Clear possible SSH error as SSH connection is now successful
  #           if r.ssh_error
  #             r.ssh_error, r.error = nil, nil
  #             r.save
  #           end
  #           PrivateMachineSimulationManager.new(r, ssh).monitor
  #         rescue Exception => e
  #           logger.error "Exception on monitoring private resource #{credentials.machine_desc}: #{e.class} - #{e}"
  #           check_record_expiration(r)
  #         end
  #       end
  #     end
  #   rescue Exception => e
  #     logger.error "SSH connection error on #{credentials.machine_desc}: #{e.class} - #{e}"
  #     records.each do |r|
  #       unless check_record_expiration(r)
  #         r.ssh_error = true
  #         r.error = "SSH connection error: (#{e.class}) #{e}"
  #         r.save
  #       end
  #     end
  #   end
  # end

  # # Used if cannot execute ScheduledPrivateMachine.monitor: remove record when it should be removed
  # def check_record_expiration(private_machine_record)
  #   machine = PrivateMachineSimulationManager.new(private_machine_record)
  #   if machine.time_limit_exceeded? or machine.experiment_end?
  #     logger.info "Removing private machine record #{private_machine_record.task_desc} due to expiration or experiment end"
  #     machine.remove_record
  #     true
  #   else
  #     false
  #   end
  # end

  # Params hash:
  # - 'credentials_id' => id of PrivateMachineCredentials record - this machine will be initialized
  def start_simulation_managers(user, instances_count, experiment_id, params = {})
    logger.debug "Start simulation managers for experiment #{experiment_id}, additional params: #{params}"

    machine_creds = PrivateMachineCredentials.find_by_id(params[:credentials_id])

    if machine_creds.nil?
      return 'error', I18n.t('infrastructure_facades.private_machine.unknown_machine_id')
    elsif machine_creds.user_id != user.id
      return 'error', I18n.t('infrastructure_facades.private_machine.no_permissions',
                             name: "#{params['login']}@#{params['host']}", scalarm_login: user.login)
    end

    instances_count.times do
      PrivateMachineRecord.new(
          user_id: user.id,
          experiment_id: experiment_id,
          credentials_id: params[:credentials_id],
          time_limit: params[:time_limit],
          start_at: params[:start_at],
          sm_uuid: SecureRandom.uuid
      ).save
    end
    ['ok', I18n.t('infrastructure_facades.private_machine.scheduled_info', count: instances_count,
                        machine_name: machine_creds.machine_desc)]
  end

  def default_additional_params
    {}
  end

  def count_scheduled_tasks(user_id)
    records = get_sm_records(user_id)
    records.nil? ? 0 : records.size
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
    'ok'
  end

  def remove_credentials(record_id, user_id, type)
    record = PrivateMachineCredentials.find_by_id(record_id)
    raise InfrastructureErrors::NoCredentialsError if record.nil?
    raise InfrastructureErrors::AccessDeniedError if record.user_id != user_id
    record.destroy
  end

  def clean_tmp_credentials(user_id, session)
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

  def simulation_manager_stop(record)
    shared_ssh_session(record.credentials).exec! "kill -9 #{record.pid}"
  end

  def simulation_manager_restart(record)
    # cannot restart server, pass
  end

  def simulation_manager_status(record)
    record.error ? :error : :running
  end

  def simulation_manager_running?(record)
    not shared_ssh_session(record.credentials).exec!("ps #{record.pid} | tail -n +2").blank?
  end

  def simulation_manager_get_log(record)
    shared_ssh_session(record.credentials).exec! "tail -25 #{record.log_path}"
  end

  def simulation_manager_install(record)
    logger.debug "Installing SM on host #{record.credentials.host}:#{record.credentials.ssh_port}"

    InfrastructureFacade.prepare_configuration_for_simulation_manager(record.sm_uuid, record.user_id,
                                                                      record.experiment_id, record.start_at)
    error_counter = 0
    while true
      begin
        record.credentials.upload_file("/tmp/scalarm_simulation_manager_#{record.sm_uuid}.zip")
        output = shared_ssh_session(record.credentials).exec! start_simulation_manager_cmd(record)
        logger.debug "SM process id: #{output}"
        record.pid = output.to_i
        if record.pid <= 0
          record.error = "Starting Simulation Manager failed with output: #{output}"
        end
        break
      rescue Exception => e
        logger.warn "Exception #{e} occured while communication with "\
"#{record.machine_desc} - #{error_counter} tries"
        error_counter += 1
        if error_counter > 10
          record.error = "Could not communicate with host. Last error: #{e}"
          break
        end
      end

      sleep(20)
    end
  end


  def start_simulation_manager_cmd(record)
    sm_dir_name = "scalarm_simulation_manager_#{record.sm_uuid}"
    chain(
        mute('source .rvm/environments/default'),
        mute(rm(sm_dir_name, true)),
        mute("unzip #{sm_dir_name}.zip"),
        mute(cd(sm_dir_name)),
        run_in_background('ruby simulation_manager.rb', record.log_path, '&1')
    )
  end

  # -- Monitoring utils --

  def after_monitoring_loop
    close_all_ssh_sessions
  end

  # --

end
