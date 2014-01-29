require_relative 'clouds/vm_instance.rb'

class CloudFacade < InfrastructureFacade

  # prefix for all created and managed VMs
  VM_NAME_PREFIX = 'scalarm_'

  # sleep time between vm checking [seconds]
  PROBE_TIME = 60
  # time to wait to VM initialization - after that, VM will be reinitialized [minutes object]
  MAX_VM_INIT_TIME = 10.minutes

  # Creates specific cloud facade instance
  # @param [Class] client_class
  def initialize(client_class)
    @client_class = client_class
    @short_name = client_class.short_name
    @full_name = client_class.full_name
  end

  def cloud_client_instance(user_id)
    cloud_secrets = CloudSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user_id)
    cloud_secrets and cloud_client = @client_class.new(cloud_secrets) or nil
  end

  # implements InfrastructureFacade
  def short_name
    @short_name
  end

  # implements InfrasctuctureFacade
  def current_state(user)
    cloud_client = cloud_client_instance(user.id)

    if cloud_client.nil?
      Rails.logger.info(log_format 'current state in GUI: lack of credentials')
      return I18n.t('infrastructure_facades.cloud.current_state_no_creds', cloud_name: @full_name)
    end

    begin
      # select all vm ids that are recorded and belong to Cloud and User
      record_vm_ids = CloudVmRecord.find_all_by_query('cloud_name'=>@short_name, 'user_id'=>user.id)
      vm_ids = cloud_client.all_vm_ids.map {|i| i} & record_vm_ids.map {|rec| rec.image_id}

      # select all existing vm's
      num = ((vm_ids.map {|vm_id| cloud_client.vm_instance(vm_id)}).select {|vm| vm.exists? }).count

      I18n.t('infrastructure_facades.cloud.current_state_count', count: num.to_s)
    rescue Exception => ex
      Rails.logger.error(log_format "current state exception:\n#{ex.backtrace}")
      I18n.t('infrastructure_facades.cloud.current_state_exception', exception: ex.to_s)
    end
  end

  # implements InfrasctuctureFacade
  def start_monitoring
    while true do
      begin
        Rails.logger.info(log_format 'monitoring thread is working')
        vm_records = CloudVmRecord.find_all_by_cloud_name(@short_name).group_by(&:user_id)

        vm_records.each do |user_id, user_vm_records|
          user = ScalarmUser.find_by_id(user_id)
          secrets = CloudSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user_id)
          if secrets.nil?
            Rails.logger.info(log_format "We cannot monitor VMs for #{user.login} due secrets lacking")
            next
          end

          client = @client_class.new(secrets)

          user_vm_records.each do |vm_record|
            vm_id = vm_record.vm_id
            Rails.logger.info(log_format 'checking', vm_id)

            vm_instance = client.vm_instance(vm_id)


            experiment = DataFarmingExperiment.find_by_id(vm_record.experiment_id)

            if (not vm_instance.exists?) or [:deactivated, :error].include?(vm_instance.status)
              Rails.logger.info(log_format 'This VM is going to be removed from our db as it is terminated', vm_id)
              temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(vm_record.sm_uuid)
              temp_pass.destroy unless temp_pass.nil?
              vm_record.destroy unless vm_record.nil?

            elsif (vm_record.time_limit_exceeded?) or experiment.nil? or (not experiment.is_running)
              Rails.logger.info(log_format 'This VM is going to be destroyed as it is done or should be done', vm_id)
              vm_instance.terminate

            elsif (vm_instance.status == :running) and (not vm_record.sm_initialized)
              Rails.logger.info(log_format 'This VM is going to be initialized with SM now', vm_id)
              initialize_sm_on(vm_record, vm_instance)

            elsif (vm_instance.status == :initializing) and (vm_record.created_at + MAX_VM_INIT_TIME < Time.now)
              Rails.logger.info(log_format "This VM will be restarted due to not being run "\
                "for more than #{MAX_VM_INIT_TIME/60} minutes", vm_id)
              vm_instance.reinitialize
              vm_record.created_at = Time.now
              vm_record.save
            end

          end
        end
      rescue Exception => e
        Rails.logger.info(log_format "Monitoring exception:\n#{e.backtrace}")
      end
      sleep(PROBE_TIME)
    end
  end

  # implements InfrasctuctureFacade
  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})

    Rails.logger.debug(log_format "Start simulation managers for experiment #{experiment_id}, additional params: #{additional_params}")
    cloud_client = cloud_client_instance(user.id)

    return 'error', I18n.t('infrastructure_facades.cloud.provide_secrets', cloud_name: @short_name) if cloud_client.nil?

    exp_image = CloudImageSecrets.find_by_query('_id'=>BSON::ObjectId(additional_params['image_id']))
    return 'error', I18n.t('infrastructure_facades.cloud.provide_image_secrets') if exp_image.nil? or exp_image.image_id.nil?
    return 'error', I18n.t('infrastructure_facades.cloud.image_permission') if exp_image.user_id != user.id
    return 'error', I18n.t('infrastructure_facades.cloud.image_cloud_error') if exp_image.cloud_name != @short_name

    sched_instances = cloud_client.schedule_vm_instances("#{VM_NAME_PREFIX}#{experiment_id}", exp_image.image_id,
                                                    instances_count, additional_params).map { |vm_id| cloud_client.vm_instance(vm_id) }

    sched_instances.each do |vm_instance|
      vm_record = CloudVmRecord.new({
                                 cloud_name: @short_name,
                                 user_id: user.id,
                                 experiment_id: experiment_id,
                                 image_id: exp_image.image_id,
                                 created_at: Time.now,
                                 time_limit: additional_params['time_limit'],
                                 vm_id: vm_instance.vm_id,
                                 sm_uuid: SecureRandom.uuid,
                                 initialized: false,
                                 start_at: additional_params['start_at'],
                             })
      vm_record.save
    end

    return 'ok', I18n.t('infrastructure_facades.cloud.scheduled_info', count: sched_instances.size,
                        cloud_name: @full_name)

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
    CloudVmRecord.find_all_by_query('cloud_name'=>@short_name, 'user_id'=>user.id) do |instance|
      instance.to_s
    end
  end

  # implements InfrasctuctureFacade
  def add_credentials(user, params, session)
    self.send("handle_#{params[:credential_type]}_credentials", user, params, session)
  end

  # implements InfrasctuctureFacade
  def clean_tmp_credentials(user_id, session)
    if session.include?(:tmp_store_secrets_in_session) and (not user_id.nil?)
      CloudSecrets.find_all_by_query('cloud_name'=>@short_name, 'user_id'=>user_id).each do |secrets|
        secrets.destroy
      end
    end

    if session.include?(:tmp_store_image_in_session) and (not user_id.nil?)
      CloudImageSecrets.find_all_by_query('cloud_name'=>@short_name, 'user_id'=>user_id).each do |image|
        image.destroy if image.experiment_id.to_s == session[:tmp_store_image_in_session].to_s
      end
    end

  end

  private

  def handle_secrets_credentials(user, params, session)

    credentials = CloudSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user.id)

    if credentials.nil?
      credentials = CloudSecrets.new({'cloud_name'=>@short_name, 'user_id' => user.id})
    end

    (params.keys.select {|k| k.start_with? 'stored_' }).each do |secret_key|
      credentials.send("#{secret_key.to_s.sub(/^stored_/, '')}=", params[secret_key])
    end
    credentials.save

    if params.include?('store_secrets_in_session')
      session[:tmp_store_secrets_in_session] = true
    else
      session.delete(:tmp_store_secrets_in_session)
    end

    'ok'
  end

  def handle_image_credentials(user, params, session)
    # TODO: use experiment id for query?
    credentials = CloudImageSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user.id,
                                                      'image_id'=>params[:image_id])

    if credentials.nil? # there is no image record with given id - create
      credentials = CloudImageSecrets.new({'cloud_name' => @short_name, 'user_id' => user.id,
                                           'experiment_id'=> params[:experiment_id], 'image_id'=>params[:image_id]})
    end

    credentials.image_login = params[:image_login]
    credentials.secret_image_password = params[:secret_image_password]

    credentials.save

    'ok'
  end

  # @param [CloudVmRecord] vm_record
  # @param [VmInstance] vm_instance
  def initialize_sm_on(vm_record, vm_instance)
    Rails.logger.debug(log_format "Initializing SM on #{vm_record.public_host}:#{vm_record.public_ssh_port}",
                                  vm_record.vm_id)

    vm_record.update_ssh_address(vm_instance) if not vm_record.public_host or not vm_record.public_ssh_port
    prepare_configuration_for_simulation_manager(vm_record.sm_uuid, vm_record.user_id, vm_record.experiment_id, vm_record.start_at)

    error_counter = 0
    while true
      begin
        #  upload the code to the VM - use only password authentication
        vm_record.upload_file("/tmp/scalarm_simulation_manager_#{vm_record.sm_uuid}.zip")
        # execute simulation manager on VM
        vm_record.ssh_session do |ssh|
          output = ssh.exec!("ls /tmp/mylogfile")
          Rails.logger.debug(log_format "SM checking output: #{output}", vm_record.vm_id)

          return unless output.include?('No such file or directory')

          output = ssh.exec!(start_simulation_manager_cmd(vm_record.sm_uuid))
          Rails.logger.debug(log_format "SM exec output: #{output}", vm_record.vm_id)
        end

        break
      rescue Exception => e
        Rails.logger.debug(log_format("Exception #{e} occured while communication with "\
"#{vm_record.public_host}:#{vm_record.public_ssh_port} - #{error_counter} tries", vm_record.vm_id))
        error_counter += 1
        if error_counter > 10
          vm_instance.terminate
          break
        end
      end

      sleep(20)
    end

    vm_record.sm_initialized = true
    vm_record.save
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


end
