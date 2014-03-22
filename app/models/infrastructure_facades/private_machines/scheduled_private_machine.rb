require 'infrastructure_facades/shell_commands'
require 'net/ssh'

class ScheduledPrivateMachine
  include ShellCommands

  attr_reader :record
  attr_reader :logger
  attr_reader :ssh_session

  def initialize(machine_record, ssh=nil)
    @record = machine_record
    @logger = InfrastructureTaskLogger.new('private_machine', machine_record.task_desc)
    @ssh_session = ssh
  end

  def upload_file(local_path, remote_path='.')
    record.upload_file local_path, remote_path
  end

  def monitor
    logger.info 'checking'

    use_ssh do |ssh|
      if time_limit_exceeded?
        logger.info 'This machine\'s task is going to be destroyed due to time limit'
        terminate_task(ssh)
        remove_record
      elsif init_time_exceeded?
        logger.info "This task was not initialized for more than #{@record.max_init_time/60} minutes, \
so Simulation Manager initialization attempts will be discontinued"
        mark_init_time_exceeded
      elsif experiment_end?
        logger.info 'This task will be destroyed due to experiment finishing'
        terminate_task(ssh)
        remove_record
      elsif sm_terminated?(ssh)
        logger.info 'Simulation Manager is terminated, but experiment has not been completed. Reporting error.'
        mark_sm_failed(ssh)
      elsif ready_to_initialize_sm?
        logger.info 'This machine is going to be initialized with SM now'
        initialize_sm(ssh)
      end
    end
  end

  def status
    record.error ? :error : :running
  end

  # -- monitoring cases --

  def time_limit_exceeded?
    record.created_at + record.time_limit.to_i.minutes < Time.now
  end

  def init_time_exceeded?
    (status != :error) and (not record.sm_initialized) and (@record.created_at + @record.max_init_time < Time.now)
  end

  def ready_to_initialize_sm?
    (status == :running) and (not @record.sm_initialized)
  end

  def sm_terminated?(ssh)
    status == :running and record.sm_initialized and ssh.exec!("ps #{record.pid} | tail -n +2").blank?
  end

  def experiment_end?
    done = @record.experiment.get_statistics[2] unless @record.experiment.nil?
    @record.experiment.nil? or (@record.experiment.is_running == false)\
      or (@record.experiment.experiment_size == done)
  end

  # -- monitoring actions --

  # TODO: inform experiments about termination
  def remove_record
    temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(@record.sm_uuid)
    temp_pass.destroy unless temp_pass.nil?
    record.destroy
  end

  def terminate_task(ssh)
    ssh.exec! "kill -9 #{record.pid}"
  end

  def mark_init_time_exceeded
    record.error = 'Simulation Manager initialization time exceeded'
    record.save
  end

  def mark_sm_failed(ssh)
    record.error = 'Simulation Manager terminated'
    record.error_log = ssh.exec! "tail -10 #{record.log_path}"
    record.save
  end

  def initialize_sm(ssh)
    logger.debug "Initializing SM on #{record.credentials.host}:#{record.credentials.ssh_port}"

    InfrastructureFacade.prepare_configuration_for_simulation_manager(record.sm_uuid, record.user_id,
                                                                      record.experiment_id, record.start_at)
    error_counter = 0
    while true
      begin
        record.upload_file("/tmp/scalarm_simulation_manager_#{record.sm_uuid}.zip")
        log_path = "/tmp/sm_log_#{record.sm_uuid}"
        output = ssh.exec!(start_simulation_manager_cmd)
        logger.debug "SM process id: #{output}"
        record.pid = output.to_i
        if record.pid <= 0
          record.error = "Starting Simulation Manager failed with output: #{output}"
        end
        break
      rescue Exception => e
        @logger.warn "Exception #{e} occured while communication with "\
"#{record.machine_desc} - #{error_counter} tries"
        error_counter += 1
        if error_counter > 10
          record.error = "Could not communicate with host. Last error: #{e}"
          break
        end
      end

      sleep(20)
    end

    record.sm_initialized = true
    record.save
  end

  def start_simulation_manager_cmd
    sm_dir_name = "scalarm_simulation_manager_#{record.sm_uuid}"
    chain(
        mute('source .rvm/environments/default'),
        mute(rm(sm_dir_name, true)),
        mute("unzip #{sm_dir_name}.zip"),
        mute(cd(sm_dir_name)),
        run_in_background('ruby simulation_manager.rb', record.log_path, '&1')
    )
  end


  # -- utils --

  def use_ssh
    if ssh_session.nil?
      credentials = PrivateMachineCredentials.find_by_user_id(record.user_id)
      # TODO: use NoCredentialsError from infrastructures-view branch
      raise String("No credentials for private machine, for user_id: #{user_id} in job_id: #{job_id}") if credentials.nil?

      logger.info 'starting new ssh session'
      Net::SSH.start(credentials.host, credentials.login,
                     password: credentials.password) do |ssh|
        yield ssh
      end
    else
      logger.debug 'using existing ssh session'
      yield ssh_session
    end
  end



end