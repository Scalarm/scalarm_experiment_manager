require 'infrastructure_facades/abstract_scheduled_job'

class ScheduledVmInstance < AbstractScheduledJob
  attr_reader :vm
  attr_reader :logger

  def initialize(vm_record, cloud_client)
    super(vm_record)
    @vm = VmInstance.new(vm_record.vm_id, cloud_client)
    @logger = InfrastructureTaskLogger.new(cloud_client.class.short_name, vm_record.vm_id)
  end

  # -- AbstractScheduledJob interface implementation --

  def name
    record.vm_id
  end

  def monitor
    logger.info 'checking'

    if vm_terminated?
      logger.info 'This VM is terminated or invalid, so it will be removed from records'
      remove_record
      # TODO: vm was terminated earlier - inform experiment
    elsif time_limit_exceeded?
      logger.info 'This VM is going to be destroyed due to time limit'
      @vm.terminate
      # TODO: vm termination - inform experiment
    elsif init_time_exceeded?
      logger.info "This VM will be restarted due to not being run "\
                "for more than #{record.max_init_time/60} minutes"
      reinitialize_with_record
    elsif experiment_end?
      logger.info 'This VM will be destroy due to experiment finishing'
      @vm.terminate
    elsif ready_to_initialize_sm?
      logger.info 'This VM is going to be initialized with SM now'
      initialize_sm
    end
  end

  def stop
    @vm.terminate
  end

  def job_status
    raise NotImplementedError
  end

  # --

  def upload_file(local_path, remote_path='.')
    record.upload_file local_path, remote_path
  end

  def ssh_session(&block)
    record.ssh_session(&block)
  end

  # -- monitoring cases --

  def vm_terminated?
    (not @vm.exists?) or [:deactivated, :error].include?(@vm.status)
  end

  def time_limit_exceeded?
    record.created_at + record.time_limit.to_i.minutes < Time.now
  end

  def init_time_exceeded?
    (@vm.status == :initializing) and (record.created_at + record.max_init_time < Time.now)
  end

  def ready_to_initialize_sm?
    (@vm.status == :running) and (not record.sm_initialized)
  end

  def experiment_end?
    done = record.experiment_instance.get_statistics[2] unless record.experiment_instance.nil?
    record.experiment_instance.nil? or (record.experiment_instance.is_running == false)\
      or (record.experiment_instance.experiment_size == done)
  end

  # -- monitoring actions --

  def remove_record
    temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(record.sm_uuid)
    temp_pass.destroy unless temp_pass.nil?
    record.destroy
  end

  def reinitialize_with_record
    @vm.reinitialize
    record.created_at = Time.now
    record.save
  end

  def initialize_sm
    update_record_ssh_address if not record.public_host or not record.public_ssh_port
    logger.debug "Initializing SM on #{record.public_host}:#{record.public_ssh_port}"

    InfrastructureFacade.prepare_configuration_for_simulation_manager(record.sm_uuid, record.user_id,
                                                                      record.experiment_id, record.start_at)

    error_counter = 0
    while true
      begin
        #  upload the code to the VM - use only password authentication
        upload_file("/tmp/scalarm_simulation_manager_#{record.sm_uuid}.zip")
        # execute simulation manager on VM
        ssh_session do |ssh|
          output = ssh.exec!("ls /tmp/mylogfile")
          logger.debug "SM checking output: #{output}"

          return unless output.include?('No such file or directory')

          output = ssh.exec!(start_simulation_manager_cmd(record.sm_uuid))
          logger.debug "SM exec output: #{output}"
        end

        break
      rescue Exception => e
        logger.warn "Exception #{e} occured while communication with "\
"#{record.public_host}:#{record.public_ssh_port} - #{error_counter} tries"
        error_counter += 1
        if error_counter > 10
          @vm.terminate
          break
        end
      end

      sleep(20)
    end

    # if there was an error on initializing, sm_initialized will be true due not to try to initialize
    record.sm_initialized = true
    record.save
  end

  def start_simulation_manager_cmd(sm_uuid)
    [
        'source .rvm/environments/default',
        "rm -rf scalarm_simulation_manager_#{sm_uuid}",
        "unzip scalarm_simulation_manager_#{sm_uuid}.zip",
        "cd scalarm_simulation_manager_#{sm_uuid}",
        'nohup ruby simulation_manager.rb  >/tmp/mylogfile 2>&1 &'
    ].join(';')
  end

  # -- vm_instance <-> vm_record utils --

  def update_record_ssh_address
    psa = @vm.public_ssh_address
    record.public_host, record.public_ssh_port = psa[:ip], psa[:port]
    record.save
  end

end