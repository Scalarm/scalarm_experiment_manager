require_relative 'private_machines/scheduled_private_machine.rb'
require_relative 'shell_commands.rb'

class PrivateMachineFacade < InfrastructureFacade

  # prefix for all created and managed VMs
  VM_NAME_PREFIX = 'scalarm_'

  def initialize
    super()
  end

  # implements InfrastructureFacade
  def short_name
    'private_machine'
  end

  # implements InfrasctuctureFacade
  def current_state(user)
    records = PrivateMachineRecord.find_all_by_user_id(user.id)
    tasks = records.nil? ? 0 : records.size
    I18n.t('infrastructure_facades.private_machine.current_state', tasks: tasks.to_s)
  end

  # implements InfrasctuctureFacade
  def monitoring_loop
    machine_records = PrivateMachineRecord.all.group_by {|r| r.private_machine_id}
    machine_records.each do |creds_id, records|
      creds = PrivateMachineCredentials.find_by_id(creds_id)
      if creds.nil?
        logger.error "Credentials missing: #{creds_id}, affected records: #{records.map &:id}"
        next
      end
      logger.debug "Monitoring private resources on: #{creds.machine_desc} (#{records.count} tasks)"
      begin
        Net::SSH.start(creds.host, creds.login, password: creds.secret_password) do |ssh|
          records.each do |r|
            # Clear possible SSH error as SSH connection is now successful
            if r.ssh_error
              r.ssh_error = nil
              r.error = nil
              r.save
            end
            ScheduledPrivateMachine.new(r, ssh).monitor
          end
        end
      rescue Net::SSH::AuthenticationFailed, SocketError, Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
        logger.error "Cannot connect with #{creds.machine_desc}: #{e}"
        records.each do |r|
          r.ssh_error = true
          r.error = "Connection error: #{e}"
          r.save
        end
        check_record_expiration(r)
      rescue Exception => e
        logger.error "Unknown exception on monitoring private resource #{creds.machine_desc}: #{e}"
        check_record_expiration(r)
      end
    end
  end

  # Used if cannot execute ScheduledPrivateMachine.monitor: remove record when it should be removed
  def check_record_expiration(private_machine_record)
    machine = ScheduledPrivateMachine.new(r)
    if machine.time_limit_exceeded? or experiment_end?
      machine.remove_record
    end
  end

  # --

  # implements InfrasctuctureFacade
  # Params hash:
  # - 'private_machine_id' => id of PrivateMachineCredentials record - this machine will be initialized
  def start_simulation_managers(user, instances_count, experiment_id, params = {})
    logger.debug "Start simulation managers for experiment #{experiment_id}, additional params: #{params}"

    machine_creds = PrivateMachineCredentials.find_by_id(params[:machine_desc])

    if machine_creds.nil?
      return 'error', I18n.t('infrastructure_facades.private_machine.unknown_machine_id')
    elsif machine_creds.user_id != user.id
      return 'error', I18n.t('infrastructure_facades.private_machine.no_permissions',
                             name: "#{params['login']}@#{params['host']}", scalarm_login: user.login)
    end

    instances_count.times do
      PrivateMachineRecord.new({
          user_id: user.id,
          experiment_id: experiment_id,
          private_machine_id: params[:machine_desc],
          created_at: Time.now,
          time_limit: params[:time_limit],
          start_at: params[:start_at],
          sm_uuid: SecureRandom.uuid,
          sm_initialized: false
                               }).save
    end
    ['ok', I18n.t('infrastructure_facades.private_machine.scheduled_info', count: instances_count,
                        machine_name: machine_creds.machine_desc)]

  end

  # implements InfrasctuctureFacade
  def default_additional_params
    {}
  end

  #def stop_simulation_managers(user, instances_count, experiment = nil)
  #  raise 'not implemented'
  #end

  # implements InfrasctuctureFacade
  def get_running_simulation_managers(user, experiment = nil)
    PrivateMachineRecord.find_all_by_user_id(user.id)
  end

  # implements InfrasctuctureFacade
  def add_credentials(user, params, session)
    credentials = PrivateMachineCredentials.new(
        'user_id'=>user.id,
        'host'=>params[:host],
        'port'=>params[:port],
        'login'=>params[:login]
    )
    credentials.secret_password = params[:secret_password]
    credentials.save
    'ok'
  end

  # implements InfrasctuctureFacade
  def clean_tmp_credentials(user_id, session)
  end


end
