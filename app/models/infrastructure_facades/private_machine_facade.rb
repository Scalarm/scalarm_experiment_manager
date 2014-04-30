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
    I18n.t('infrastructure_facades.private_machine.current_state', tasks: count_scheduled_tasks(user))
  end

  # implements InfrasctuctureFacade
  def monitoring_loop
    machine_records = PrivateMachineRecord.all.group_by {|r| r.credentials_id}
    machine_threads = []
    machine_records.each do |creds_id, records|
      credentials = PrivateMachineCredentials.find_by_id(creds_id)
      if credentials.nil?
        logger.error "Credentials missing: #{creds_id}, affected records: #{records.map &:id}"
        records.map {|r| check_record_expiration(r)}
        next
      end
      machine_threads << Thread.start { monitor_machine_records(credentials, records) }
    end
    machine_threads.map &:join
  end

  def monitor_machine_records(credentials, records)
    logger.debug "Monitoring private resources on: #{credentials.machine_desc} (#{records.count} tasks)"
    begin
      credentials.ssh_start do |ssh|
        records.each do |r|
          begin
            # Clear possible SSH error as SSH connection is now successful
            if r.ssh_error
              r.ssh_error, r.error = nil, nil
              r.save
            end
            ScheduledPrivateMachine.new(r, ssh).monitor
          rescue Exception => e
            logger.error "Exception on monitoring private resource #{credentials.machine_desc}: #{e.class} - #{e}"
            check_record_expiration(r)
          end
        end
      end
    rescue Exception => e
      logger.error "SSH connection error on #{credentials.machine_desc}: #{e.class} - #{e}"
      records.each do |r|
        unless check_record_expiration(r)
          r.ssh_error = true
          r.error = "SSH connection error: (#{e.class}) #{e}"
          r.save
        end
      end
    end
  end

  # Used if cannot execute ScheduledPrivateMachine.monitor: remove record when it should be removed
  def check_record_expiration(private_machine_record)
    machine = ScheduledPrivateMachine.new(private_machine_record)
    if machine.time_limit_exceeded? or machine.experiment_end?
      logger.info "Removing private machine record #{private_machine_record.task_desc} due to expiration or experiment end"
      machine.remove_record
      true
    else
      false
    end
  end

  # --

  # implements InfrasctuctureFacade
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
      PrivateMachineRecord.new({
          user_id: user.id,
          experiment_id: experiment_id,
          credentials_id: params[:credentials_id],
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

  def count_scheduled_tasks(user)
    records = get_running_simulation_managers(user)
    records.nil? ? 0 : records.size
  end

  # implements InfrasctuctureFacade
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

  # implements InfrasctuctureFacade
  def clean_tmp_credentials(user_id, session)
  end


end