require_relative 'clouds/vm_instance.rb'

class CloudFacade < InfrastructureFacade

  # prefix for all created and managed VMs
  VM_NAME_PREFIX = 'scalarm_'

  attr_reader :long_name
  attr_reader :short_name

  attr_reader :ssh_sessions

  # Creates specific cloud facade instance
  # @param [Class] client_class
  def initialize(client_class)
    @client_class = client_class
    @short_name = client_class.short_name
    @long_name = client_class.long_name
    @ssh_sessions = {}
    super()
  end

  def cloud_client_instance(user_id)
    cloud_secrets = get_cloud_secrets(user_id)
    cloud_secrets ? @client_class.new(cloud_secrets) : nil
  end

  def get_cloud_secrets(user_id)
    @secret ||= CloudSecrets.find_by_query(cloud_name: @short_name, user_id: user_id)
  end

  def sm_record_class
    CloudVmRecord
  end

  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    logger.debug "Start simulation managers for experiment #{experiment_id}, additional params: #{additional_params}"
    begin
      cloud_client = cloud_client_instance(user_id)
    rescue
      return 'error', I18n.t('infrastructure_facades.cloud.client_problem', cloud_name: @short_name)
    end

    return 'error', I18n.t('infrastructure_facades.cloud.provide_secrets', cloud_name: @short_name) if cloud_client.nil?

    begin

      exp_image = CloudImageSecrets.find_by_id(additional_params['image_secrets_id'])
      if exp_image.nil? or exp_image.image_id.nil?
        return 'error', I18n.t('infrastructure_facades.cloud.provide_image_secrets')
      elsif not cloud_client.image_exists? exp_image.image_id
        return 'error', I18n.t('infrastructure_facades.cloud.image_not_exists',
                               image_id: exp_image.image_id, cloud_name: @long_name)
      elsif exp_image.user_id != user_id
        return 'error', I18n.t('infrastructure_facades.cloud.image_permission')
      elsif exp_image.cloud_name != @short_name
        return 'error', I18n.t('infrastructure_facades.cloud.image_cloud_error')
      end

      sched_instances = schedule_vm_instances(cloud_client, "#{VM_NAME_PREFIX}#{experiment_id}", exp_image,
                                                        instances_count, user_id, experiment_id, additional_params)

      ['ok', I18n.t('infrastructure_facades.cloud.scheduled_info', count: sched_instances.size,
                          cloud_name: @long_name)]
    rescue Exception => e
      Rails.logger.error "Exception when staring simulation managers: #{e.class} - #{e.to_s}\n#{e.backtrace.join("\n")}"
      ['error', I18n.t('infrastructure_facades.cloud.scheduled_error', error: e.message)]
    end

  end

  # Intantiate virtual machines and add records to database
  # @return [Array<ScheduledVmInstance>]
  def schedule_vm_instances(cloud_client, base_name, image_secrets, number, user_id, experiment_id, params)
    cloud_client.instantiate_vms(base_name, image_secrets.image_id, number, params).map do |vm_id|

      vm_record = CloudVmRecord.new({
                                        cloud_name: cloud_client.class.short_name,
                                        user_id: user_id,
                                        experiment_id: experiment_id,
                                        image_secrets_id: image_secrets.id,
                                        time_limit: params['time_limit'],
                                        vm_id: vm_id.to_s,
                                        sm_uuid: SecureRandom.uuid,
                                        start_at: params['start_at'],
                                        instance_type: params['instance_type']
                                    })
      vm_record.initialize_fields
      vm_record.save

      create_simulation_manager(vm_record)
    end
  end

  def add_credentials(user, params, session)
    self.send("handle_#{params[:credential_type]}_credentials", user, params, session)
  end

  def remove_credentials(record_id, user_id, type)
    record_class = case type
                     when 'secrets' then CloudSecrets
                     when 'image' then CloudImageSecrets
                     else raise StandardError.new("Usupported credentials type: #{type}")
                   end

    record = record_class.find_by_id(record_id)
    raise InfrastructureErrors::NoCredentialsError if record.nil?
    raise InfrastructureErrors::AccessDeniedError if record.user_id != user_id
    record.destroy
  end

  def get_sm_records(user_id=nil, experiment_id=nil, params={})
    query = {cloud_name: @short_name}
    query.merge!({user_id: user_id}) if user_id
    query.merge!({experiment_id: experiment_id}) if experiment_id

    CloudVmRecord.where(query)
  end

  def get_sm_record_by_id(record_id)
    CloudVmRecord.find_by_id(record_id)
  end

  # -- SimulationManager delegation methods --

  def _simulation_manager_stop(record)
    cloud_client_instance(record.user_id).terminate(record.vm_id)
  end

  def _simulation_manager_restart(record)
    cloud_client_instance(record.user_id).reinitialize(record.vm_id)
  end

  def _simulation_manager_resource_status(record)
    vm_status = cloud_client_instance(record.user_id).status(record.vm_id)
    if vm_status == :running
      begin
        # VM is running, so check SSH connection
        record.update_ssh_address!(cloud_client_instance(record.user_id).vm_instance(record.vm_id)) unless record.has_ssh_address?
        if record.has_ssh_address?
          shared_ssh_session(record)
          :running
        else
          :initializing
        end
      rescue Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => e
        # remember this error in case of unable to initialize
        record.error_log = e.to_s
        record.save
        :initializing
      rescue Exception => e
        logger.info "Exception on SSH connection test to #{record.public_host}:#{record.public_ssh_port}:"\
"#{e.class} #{e.to_s}"
        record.store_error('ssh', e.to_s)
        _simulation_manager_stop(record)
        :error
      end
    else
      vm_status
    end
  end

  def _simulation_manager_running?(record)
    vm = cloud_client_instance(record.user_id).vm_instance(record.vm_id)
    if vm.exists? and vm.status == :running
      not shared_ssh_session(record).exec!("ps #{record.pid} | tail -n +2").blank?
    else
      false
    end
  end

  def _simulation_manager_get_log(record)
    shared_ssh_session(record).exec! "tail -25 #{record.log_path}"
  end

  def _simulation_manager_install(record)
    record.update_ssh_address!(cloud_client_instance(record.user_id).vm_instance(record.vm_id)) unless record.has_ssh_address?
    logger.debug "Installing SM on VM: #{record.public_host}:#{record.public_ssh_port}"

    InfrastructureFacade.prepare_configuration_for_simulation_manager(record.sm_uuid, record.user_id,
                                                                      record.experiment_id, record.start_at)
    error_counter = 0
    while true
      begin
        ssh = shared_ssh_session(record)
        break if log_exists?(record, ssh) or send_and_launch_sm(record, ssh)
      rescue Exception => e
        logger.warn "Exception #{e} occured while communication with "\
"#{record.public_host}:#{record.public_ssh_port} - #{error_counter} tries"
        error_counter += 1
        if error_counter > 10
          logger.error 'Exceeded number of SimulationManager installation attempts'
          record.store_error('install_failed', e.to_s)
          _simulation_manager_stop(record)
        end
      end

      sleep(20)
    end
  end

  def to_h
    {
        name: long_name,
        group: 'cloud',
        infrastructure_name: short_name,
    }
  end

  # -- Monitoring utils --

  def clean_up_resources
    close_all_ssh_sessions
  end

  # --

  private

  def handle_secrets_credentials(user, params, session)

    credentials = CloudSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user.id)

    if credentials.nil?
      credentials = CloudSecrets.new({'cloud_name'=>@short_name, 'user_id' => user.id})
    end

    (params.keys.select {|k| k.start_with? 'stored_' }).each do |key|
      credentials.send("#{key.to_s.sub(/^stored_/, '')}=", params[key])
    end

    (params.keys.select {|k| k.start_with? 'upload_' }).each do |key|
      credentials.send("#{key.to_s.sub(/^upload_/, '')}=", params[key].read)
    end

    credentials.save

    'ok'
  end

  def handle_image_credentials(user, params, session)
    image_id, label = params[:image_info].split(';')

    credentials = CloudImageSecrets.new(cloud_name: @short_name, user_id: user.id,
                                        image_id: image_id, label: label)

    credentials.image_login = params[:image_login]
    credentials.secret_image_password = params[:secret_image_password]

    credentials.save

    'ok'
  end


end
