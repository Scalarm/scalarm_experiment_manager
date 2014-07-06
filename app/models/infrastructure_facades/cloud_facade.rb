require_relative 'clouds/vm_instance.rb'
require_relative 'shared_ssh'
require_relative 'infrastructure_errors'
require_relative 'clouds/cloud_errors'

class CloudFacade < InfrastructureFacade
  include ShellCommands
  include SharedSSH
  include ShellBasedInfrastructure

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
    raise InfrastructureErrors::NoCredentialsError.new if cloud_secrets.nil?
    raise InfrastructureErrors::InvalidCredentialsError.new if cloud_secrets.invalid
    cloud_secrets ? @client_class.new(cloud_secrets) : nil
  end

  def get_cloud_secrets(user_id)
    @secret ||= CloudSecrets.find_by_query(cloud_name: @short_name, user_id: user_id)
  end

  def sm_record_class
    CloudVmRecord
  end

  def start_simulation_managers(user_id, instances_count, experiment_id, params = {})
    logger.debug "Start simulation managers for experiment #{experiment_id}, additional params: #{params}"

    begin
      image_secrets_id = params['image_secrets_id']
      get_and_validate_image_secrets(image_secrets_id, user_id)
      records = create_and_save_records(instances_count, image_secrets_id, user_id, experiment_id,
                              params['time_limit'], params['start_at'], params['instance_type'],
                              find_stored_params(params))

      ['ok', I18n.t('infrastructure_facades.cloud.scheduled_info', count: records.count,
                          cloud_name: @long_name)]
    rescue CloudErrors::ImageValidationError => ive
      logger.error "Error validating image secrets: #{ive.to_s}"
      ['error', I18n.t("infrastructure_facades.cloud.#{ive.to_s}", default: ive.to_s)]
    rescue Exception => e
      logger.error "Exception when staring simulation managers: #{e.class} - #{e.to_s}\n#{e.backtrace.join("\n")}"
      ['error', I18n.t('infrastructure_facades.cloud.scheduled_error', error: e.message)]
    end

  end

  def find_stored_params(params)
    Hash[(params.keys.select {|k| k.start_with? 'stored_' }).map do |key|
      [key.to_s.sub(/^stored_/, ''), params[key]]
    end]
  end

  def get_and_validate_image_secrets(image_secrets_id, user_id)
    exp_image = CloudImageSecrets.find_by_id(image_secrets_id)
    if exp_image.nil? or exp_image.image_id.nil?
      raise CloudErrors::ImageValidationError.new 'provide_image_secrets'
    elsif not cloud_client_instance(user_id).image_exists? exp_image.image_id
      raise CloudErrors::ImageValidationError.new 'image_not_exists'
    elsif exp_image.user_id != user_id
      raise CloudErrors::ImageValidationError.new 'image_permission'
    elsif exp_image.cloud_name != @short_name
      raise CloudErrors::ImageValidationError.new 'image_cloud_error'
    end

    exp_image
  end

  # Intantiate virtual machine and save vm_id to given record
  def schedule_vm_instance(record)
    cloud_client = cloud_client_instance(record.user_id)
    vm_id = cloud_client.instantiate_vms('scalarm', record.image_secrets.image_id, 1,
                                         record.params.merge('instance_type' => record.instance_type)).first
    record.vm_id = vm_id
    record.save
    record
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
    cloud_client = nil
    begin
      cloud_client = cloud_client_instance(record.user_id)
      return :not_available unless cloud_client and cloud_client.valid_credentials?
    rescue Exception
      return :not_available
    end

    vm_id = record.vm_id
    if vm_id
      vm_status = cloud_client.status(vm_id)
      case vm_status
        when :initializing then :initializing
        when :running
          begin
            # VM is running, so check SSH connection
            record.update_ssh_address!(cloud_client_instance(record.user_id).vm_instance(record.vm_id)) unless record.has_ssh_address?
            if record.has_ssh_address?
              ssh = shared_ssh_session(record)
              return (record.pid and app_running?(ssh, record.pid) and :running_sm or :ready)
            else
              return :initializing
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
        when :deactivated then :released
        else :error
      end

    else
      :available
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
          break
        end
      end

      sleep(20)
    end
  end

  def _simulation_manager_prepare_resource(record)
    begin
      schedule_vm_instance(record)
    rescue Exception => error
      logger.error "Exception when instantiating VMs for user #{record.user_id}: #{error.to_s}\n#{error.backtrace.join("\n")}"
      record.store_error('install_failed', "#{error.to_s}\n#{error.backtrace.join("\n")}")
    end
  end

  def create_record(image_secrets_id, user_id, experiment_id, time_limit, start_at, instance_type, params)
    vm_record = CloudVmRecord.new({
                                      cloud_name: short_name,
                                      user_id: user_id,
                                      experiment_id: experiment_id,
                                      image_secrets_id: image_secrets_id,
                                      time_limit: time_limit,
                                      sm_uuid: SecureRandom.uuid,
                                      start_at: start_at,
                                      instance_type: instance_type,
                                      params: params
                                  })
    vm_record.initialize_fields
    vm_record
  end

  def create_and_save_records(count, image_secrets_id, user_id, experiment_id, time_limit, start_at, instance_type, params)
    records = (1..count).map do
      create_record(image_secrets_id, user_id, experiment_id, time_limit, start_at, instance_type, params)
    end
    records.each &:save
    records
  end

  def enabled_for_user?(user_id)
    creds = CloudSecrets.find_by_query(user_id: user_id, cloud_name: @short_name)
    !!(creds and not creds.invalid)
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
    credentials
  end

  def handle_image_credentials(user, params, session)
    image_id, label = params[:image_info].split(';')

    credentials = CloudImageSecrets.new(cloud_name: @short_name, user_id: user.id,
                                        image_id: image_id, label: label)

    credentials.image_login = params[:image_login]
    credentials.secret_image_password = params[:secret_image_password]

    credentials.save
    credentials
  end


end
