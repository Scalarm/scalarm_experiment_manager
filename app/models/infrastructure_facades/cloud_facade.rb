require_relative 'clouds/vm_instance.rb'

class CloudFacade < InfrastructureFacade

  # prefix for all created and managed VMs
  VM_NAME_PREFIX = 'scalarm_'

  attr_reader :long_name
  attr_reader :short_name

  # Creates specific cloud facade instance
  # @param [Class] client_class
  def initialize(client_class)
    @client_class = client_class
    @short_name = client_class.short_name
    @long_name = client_class.long_name
    super()
  end

  def cloud_client_instance(user_id)
    cloud_secrets = get_cloud_secrets(user_id)
    cloud_secrets ? @client_class.new(cloud_secrets) : nil
  end

  def get_cloud_secrets(user_id)
    @secret ||= CloudSecrets.find_by_query(cloud_name: @short_name, user_id: user_id)
  end

  # -- InfrasctuctureFacade implementation --

  def current_state(user)
    I18n.t('infrastructure_facades.cloud.current_state_count', count: get_sm_records(user.id).count)
  end

  def monitoring_loop
    get_sm_records.group_by(&:user_id).each do |user_id, user_vm_records|
      secrets = get_cloud_secrets(user_id)
      if secrets.nil?
        user = ScalarmUser.find_by_id(user_id)
        logger.info "We cannot monitor VMs for #{user.login} due secrets lacking"
        next
      end

      client = @client_class.new(secrets)
      (user_vm_records.map {|r| client.scheduled_vm_instance(r)}).each &:monitor
    end
  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    logger.debug "Start simulation managers for experiment #{experiment_id}, additional params: #{additional_params}"
    begin
      cloud_client = cloud_client_instance(user.id)
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
      elsif exp_image.user_id != user.id
        return 'error', I18n.t('infrastructure_facades.cloud.image_permission')
      elsif exp_image.cloud_name != @short_name
        return 'error', I18n.t('infrastructure_facades.cloud.image_cloud_error')
      end

      sched_instances = schedule_vm_instances(cloud_client, "#{VM_NAME_PREFIX}#{experiment_id}", exp_image,
                                                        instances_count, user.id, experiment_id, additional_params)

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
                                        created_at: Time.now,
                                        time_limit: params['time_limit'],
                                        vm_id: vm_id.to_s,
                                        sm_uuid: SecureRandom.uuid,
                                        sm_initialized: false,
                                        start_at: params['start_at'],
                                    })
      vm_record.save

      cloud_client.scheduled_vm_instance(vm_record)
    end
  end

  def default_additional_params
    {}
  end

  def add_credentials(user, params, session)
    self.send("handle_#{params[:credential_type]}_credentials", user, params, session)
  end

  def clean_tmp_credentials(user_id, session)
  end

  def get_simulation_managers(user_id=nil, experiment_id=nil, params={})
    vm_records = get_sm_records(user_id, experiment_id, params)
    secrets = get_cloud_secrets(user_id)
    if secrets.nil?
      []
    else
      client = @client_class.new(secrets)
      vm_records.map {|r| client.cloud_simulation_manager(r)}
    end
  end

  def get_sm_records(user_id=nil, experiment_id=nil, params={})
    query = {cloud_name: @short_name}
    query.merge!({user_id: user_id}) if user_id
    query.merge!({experiment_id: experiment_id}) if experiment_id

    CloudVmRecord.find_all_by_query(query)
  end

  def get_sm_record_by_id(record_id)
    CloudVmRecord.find_by_id(record_id)
  end

  def create_simulation_manager(record)
    CloudSimulationManager.new(record, cloud_client_instance(CloudSecrets.find_by_id(record.user_id)))
  end

  # --

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

    'ok'
  end

  def handle_image_credentials(user, params, session)
    credentials = CloudImageSecrets.new(cloud_name: @short_name, user_id: user.id,
                                        image_id: params[:image_id])

    credentials.image_login = params[:image_login]
    credentials.secret_image_password = params[:secret_image_password]

    credentials.save

    'ok'
  end


end
