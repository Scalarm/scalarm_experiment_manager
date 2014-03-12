require_relative 'clouds/vm_instance.rb'
require_relative 'simulation_managers_container.rb'

class CloudFacade < InfrastructureFacade
  include SimulationManagersContainer

  # prefix for all created and managed VMs
  VM_NAME_PREFIX = 'scalarm_'

  # sleep time between vm checking [seconds]
  PROBE_TIME = 60

  # Creates specific cloud facade instance
  # @param [Class] client_class
  def initialize(client_class)
    @client_class = client_class
    @short_name = client_class.short_name
    @long_name = client_class.long_name
    super()
  end

  def cloud_client_instance(user_id)
    cloud_secrets = CloudSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user_id)
    cloud_secrets ? @client_class.new(cloud_secrets) : nil
  end

  # -- InfrasctuctureFacade implementation --

  def current_state(user)
    cloud_client = cloud_client_instance(user.id)

    if cloud_client.nil?
      logger.info  'current state in GUI: lack of credentials'
      return I18n.t('infrastructure_facades.cloud.current_state_no_creds', cloud_name: @long_name)
    end

    begin
      # select all vm ids that are recorded and belong to Cloud and User
      record_vm_ids = CloudVmRecord.find_all_by_query('cloud_name'=>@short_name, 'user_id'=>user.id)
      vm_ids = cloud_client.all_vm_ids.map {|i| i} & record_vm_ids.map {|rec| rec.vm_id}

      # select all existing vm's
      num = ((vm_ids.map {|vm_id| cloud_client.vm_instance(vm_id)}).select {|vm| vm.exists? }).count

      I18n.t('infrastructure_facades.cloud.current_state_count', count: num.to_s)
    rescue Exception => ex
      logger.error "current state exception:\n#{ex.backtrace.join("\n")}"
      I18n.t('infrastructure_facades.cloud.current_state_exception', exception: ex.to_s)
    end
  end

  def start_monitoring
    while true do
      begin
        logger.info 'monitoring thread is working'
        vm_records = CloudVmRecord.find_all_by_cloud_name(@short_name).group_by(&:user_id)

        vm_records.each do |user_id, user_vm_records|
          secrets = CloudSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user_id)
          if secrets.nil?
            logger.info "We cannot monitor VMs for #{user.login} due secrets lacking"
            next
          end

          client = @client_class.new(secrets)
          (user_vm_records.map {|r| client.cloud_simulation_manager(r)}).each &:monitor

        end
      rescue Exception => e
        logger.error "Monitoring exception: #{e}\n#{e.backtrace.join("\n")}"
      end
      sleep(PROBE_TIME)
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

      exp_image = CloudImageSecrets.find_by_id(additional_params['image_id'])
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

      sched_instances = cloud_client.schedule_instances("#{VM_NAME_PREFIX}#{experiment_id}", exp_image.image_id,
                                                        instances_count, user.id, experiment_id, additional_params)

      ['ok', I18n.t('infrastructure_facades.cloud.scheduled_info', count: sched_instances.size,
                          cloud_name: @long_name)]
    rescue Exception => e
      ['error', I18n.t('infrastructure_facades.cloud.scheduled_error', error: e.message)]
    end

  end

  def default_additional_params
    {}
  end

  #def stop_simulation_managers(user, instances_count, experiment = nil)
  #  raise 'not implemented'
  #end

  def get_running_simulation_managers(user, experiment = nil)
    CloudVmRecord.find_all_by_query('cloud_name'=>@short_name, 'user_id'=>user.id) do |instance|
      instance.to_s
    end
  end

  def add_credentials(user, params, session)
    self.send("handle_#{params[:credential_type]}_credentials", user, params, session)
  end

  def clean_tmp_credentials(user_id, session)
  end

  # --

  # -- AbstractSimulationManager implementation --

  attr_reader :long_name
  attr_reader :short_name

  def sm_record(resource_id, user_id)
    CloudVmRecord.find_by_query('cloud_name'=>@short_name, 'user_id'=>user_id, 'vm_id'=>resource_id)
  end

  def all_user_sm_records(user_id)
    CloudVmRecord.find_all_by_query('cloud_name'=>@short_name, 'user_id'=>user_id)
  end

  def all_user_simulation_managers(user_id)
    vm_records = all_user_sm_records(user_id)
    secrets = CloudSecrets.find_by_query('cloud_name'=>@short_name, 'user_id'=>user_id)
    if secrets.nil?
      []
    else
      client = @client_class.new(secrets)
      vm_records.map {|r| client.cloud_simulation_manager(r)}
    end
  end

  def simulation_manager(resource_id, user_id)
    query = {'cloud_name'=>@short_name, 'user_id'=>user_id}
    vm_record = CloudVmRecord.find_by_query(query.merge('vm_id'=>resource_id))
    secrets = CloudSecrets.find_by_query(query)
    if vm_record and secrets
      client = @client_class.new(secrets)
      client.cloud_simulation_manager(vm_record)
    else
      nil
    end
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


end
