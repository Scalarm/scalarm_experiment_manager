require 'yaml'

require_relative 'infrastructure_task_logger'
require_relative 'infrastructure_errors'
require_relative 'simulation_manager'

require 'thread_pool'
require 'mongo_lock'

# Methods necessary to implement by subclasses:
#
# - long_name() -> String - name of infrastructure which will be presented to GUI user; should be localized
# - short_name() -> String - used as infrastructure id
#
# - start_simulation_managers(user, job_counter, experiment_id, additional_params) - starting jobs/vms with Simulation Managers
# - add_credentials(user, params, session) -> credentials record [MongoActiveRecord] - save credentials to database
#  -- all params keys are converted to symbols and values are stripped
# - remove_credentials(record_id, user_id, params) - remove credentials for this infrastructure (e.g. user credentials)
# - get_credentials(user_id, params) - show collection of credentials records for this infrastructure
# - enabled_for_user?(user_id) -> true/false - if user with user_id can use this infrastructure
#
# Database support methods:
# - _get_sm_records(query, params={}) -> Array of SimulationManagerRecord subclass instances
# - get_sm_record_by_id(record_id) -> SimulationManagerRecord subclass instance
#
# SimulationManager delegate methods to implement
# - _simulation_manager_stop(record) - stop Simulation Manager execution and free used computational resources
# - _simulation_manager_restart(record) - restart Simulation Manager and/or computational resource (used to reinitialize)
# - _simulation_manager_resource_status(record) - return one of: [:initializing, :running, :deactivated, :error] state
#  -- state refers only to state of computational resource (e.g. VM), not to Simulation Manager application state
# - _simulation_manager_running?(record) - true/false - is Simulation Manager _application_ running? (e.g. check UNIX process state)
# - _simulation_manager_get_log(record) -> String - get content of Simulation Manager application log file (stdout+stderr)
#  -- usually cutted to over a dozen of lines)
# - _simulation_manager_install(record) - sends to computational resource and executes Simulation Manager application
#
# Methods which can be overriden, but not necessarily:
# - default_additional_params() -> Hash - default additional parameters necessary to start Simulation Managers with the facade
# - init_resources() - initialize resources needed to perform operations on Simulation Managers
#   -- this method will be invoked before executing yield_simulation_manager(s) block
# - clean_up_resources() - close resources needed to perform operations on Simulation Managers
#   -- this method will be invoked after executing yield_simulation_manager(s) block
# - create_simulation_manager(record) - create SimulationManager instance on SMRecord base
#   -- typically you will not override this method, but sometimes custom SimulationManager is needed
#   -- this method should not be used directly
# - _simulation_manager_before_monitor(record) - executed before monitoring single resource
# - _simulation_manager_after_monitor(record) - executed after monitoring single resource
# - destroy_unused_credentials(authentication_mode, user) - destroy infrastructure credentials which are not used anymore



class InfrastructureFacade
  include InfrastructureErrors

  attr_reader :logger

  def initialize
    @logger = InfrastructureTaskLogger.new short_name
  end

  def self.prepare_configuration_for_simulation_manager(sm_uuid, user_id, experiment_id, start_at = '')
    Rails.logger.debug "Preparing configuration for Simulation Manager with id: #{sm_uuid}"

    Dir.chdir('/tmp')
    # using simulation manager implementation based on application config
    if Rails.configuration.simulation_manager_version == :go
      # TODO checking somehow the destination server architecture
      FileUtils.cp_r(File.join(Rails.root, 'public', 'scalarm_simulation_manager_go', 'linux_386'), "scalarm_simulation_manager_#{sm_uuid}")
    elsif Rails.configuration.simulation_manager_version == :ruby
      FileUtils.cp_r(File.join(Rails.root, 'public', 'scalarm_simulation_manager_ruby'), "scalarm_simulation_manager_#{sm_uuid}")
    end

    # prepare sm configuration
    temp_password = SimulationManagerTempPassword.find_by_sm_uuid(sm_uuid)
    temp_password = SimulationManagerTempPassword.create_new_password_for(sm_uuid, experiment_id) if temp_password.nil?

    sm_config = {
        experiment_id: experiment_id,
        information_service_url: Rails.application.secrets.information_service_url,
        experiment_manager_user: temp_password.sm_uuid,
        experiment_manager_pass: temp_password.password,
        insecure_ssl: (Rails.application.secrets.include?(:insecure_ssl) ? Rails.application.secrets.insecure_ssl : true) # TODO insecure SSL by default
    }

    unless start_at.blank?
      sm_config['start_at'] = Time.parse(start_at)
    end

    if Rails.application.secrets.include?(:sm_information_service_url)
      sm_config['information_service_url'] = Rails.application.secrets.sm_information_service_url
    end

    Rails.logger.debug("Development mode set ? : #{!!Rails.application.secrets.information_service_development}")

    if !!Rails.application.secrets.information_service_development
      sm_config['development'] = true
    end

    if Rails.application.secrets.include? :certificate_path
      remote_name = 'scalarm_cert.pem'
      cert_path = Rails.application.secrets.certificate_path
      FileUtils.cp(cert_path, File.join("scalarm_simulation_manager_#{sm_uuid}", remote_name))
      sm_config[:scalarm_certificate_path] = remote_name
    end

    IO.write("/tmp/scalarm_simulation_manager_#{sm_uuid}/config.json", sm_config.to_json)
    # zip all files
    %x[zip /tmp/scalarm_simulation_manager_#{sm_uuid}.zip scalarm_simulation_manager_#{sm_uuid}/*]
    Dir.chdir(Rails.root)
  end

  def self.prepare_monitoring_package(sm_uuid, user_id, infrastructure_name)
    Rails.logger.debug "Preparing monitoring package for Simulation Manager with id: #{sm_uuid}"

    Dir.mkdir(File.join('/tmp', monitoring_package_dir(sm_uuid))) unless Dir.exist?(File.join('/tmp', monitoring_package_dir(sm_uuid)))
    # prepare sm configuration
    temp_password = SimulationManagerTempPassword.where(user_id: user_id).first

    if temp_password.nil?
      temp_password = SimulationManagerTempPassword.new(
          sm_uuid: sm_uuid,
          password: SecureRandom.base64,
          user_id: user_id
      )

      temp_password.save
    end

    sm_config = {
        InformationServiceAddress: (Rails.application.secrets.sm_information_service_url or
            Rails.application.secrets.information_service_url),
        Login: temp_password.sm_uuid,
        Password: temp_password.password,
        InsecureSSL: (Rails.application.secrets.include?(:insecure_ssl) ? Rails.application.secrets.insecure_ssl : true), # TODO insecure SSL by default
        Infrastructures: [ infrastructure_name ],
    }

    if Rails.application.secrets.include? :certificate_path
      sm_config[:ScalarmCertificatePath] = '.scalarm_certificate'
    end

    if Rails.application.secrets.include?(:sm_information_service_url)
      sm_config[:InformationServiceAddress] = Rails.application.secrets.sm_information_service_url
    end

    IO.write(File.join('/tmp', monitoring_package_dir(sm_uuid), 'config.json'), sm_config.to_json)
    # zip all files
    Dir.chdir(Rails.root)
  end

  # TODO: for bakckward compatibility
  def current_state(user_id)
    "You have #{count_sm_records} Simulation Managers scheduled"
  end

  def monitoring_thread
    configure_polling_interval
    lock = Scalarm::MongoLock.new(short_name)

    while true do
      if lock.acquire
        logger.info 'monitoring thread is working'
        begin
          monitoring_loop
        rescue Exception => e
          logger.error "Uncaught monitoring exception: #{e.class}, #{e}\n#{e.backtrace.join("\n")}"
        end
        lock.release
      end
      sleep(@polling_interval_sec)
    end
  end

  def monitoring_loop
    begin
      yield_grouped_simulation_managers do |grouped_simulation_managers|
        ThreadPool.use([grouped_simulation_managers.count, 4].min) do |pool|
          grouped_simulation_managers.each do |group, simulation_managers|
            pool.schedule do
              begin
                simulation_managers.each &:monitor
              rescue Exception => e
                logger.error "Uncaught exception on monitoring group computation thread (#{group.to_s}): #{e.to_s}\n#{e.backtrace.join("\n")}"
                get_grouped_sm_records[group].select(&:should_destroy?).each do |record|
                  logger.warn "Record #{record.id} will be destroyed"
                  record.destroy
                end
              end
            end
          end
        end
      end
    rescue Exception => e
      logger.error "Uncaught exception in monitoring loop: #{e.to_s}\n#{e.backtrace.join("\n")}"
    end
  end

  def configure_polling_interval
    config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
    @polling_interval_sec = config.has_key?('monitoring') ? config['monitoring']['interval'].to_i : 60
    logger.debug "Setting polling interval to #{@polling_interval_sec} seconds"
  end

  def schedule_simulation_managers(user_id, experiment_id, job_counter, additional_params=nil)
    additional_params = default_additional_params.merge(additional_params)
    status, response_msg = start_simulation_managers(user_id, job_counter, experiment_id, additional_params)

    render json: response_msg, status: status
  end

  def get_grouped_sm_records(*args)
    get_sm_records(*args).group_by &:monitoring_group
  end

  # Use only for creating _single_ SimulationManager based on some record
  # For many SM use yield_simulation_managers()
  # This method ensures that resources used by SM will be cleaned up
  def yield_simulation_manager(record, &block)
    begin
      init_resources
      yield create_simulation_manager(record)
    ensure
      clean_up_resources
    end
  end

  # This method ensures that resources used by SM will be cleaned up
  def yield_simulation_managers(*args, &block)
    sm_records = get_sm_records(*args)
    if sm_records.empty?
      yield []
    else
      begin
        init_resources
        yield sm_records.map {|r| create_simulation_manager(r)}
      ensure
        clean_up_resources
      end
    end
  end

  # This method ensures that resources used by SM will be cleaned up
  def yield_grouped_simulation_managers(*args, &block)
    yield_simulation_managers(*args) do |simulation_managers|
      yield simulation_managers.group_by {|sm| sm.record.monitoring_group}
    end
  end

  # If user_id is given, completes data with user-specific information about infrastructure
  # @return [Hash] used mainly for listing general infrastructure information in InfrastructureController
  def to_h(user_id=nil)
    base = {
        name: long_name,
        infrastructure_name: short_name
    }

    user_id ? base.merge(enabled: enabled_for_user?(user_id)) : base
  end

  # Helper for Infrastrucutres Tree
  def sm_record_hashes(user_id, experiment_id=nil, params={})
    get_sm_records(user_id, experiment_id, params).map {|r| r.to_h }
  end

  def default_additional_params
    { 'time_limit' => 60 }
  end

  def count_sm_records(user_id=nil, experiment_id=nil, attributes=nil)
    get_sm_records(user_id, experiment_id, attributes).count
  end

  def other_params_for_booster(user_id)
    {}
  end

  def get_credentials(*args)
    raise NotImplementedError
  end

  # -- SimulationManger delegation default implementation --

  def _simulation_manager_before_monitor(record); end
  def _simulation_manager_after_monitor(record); end

  def create_simulation_manager(record)
    SimulationManager.new(record, self)
  end

  def init_resources; end
  def clean_up_resources; end

  def self.monitoring_package_dir(sm_uuid)
    "scalarm_monitoring_#{sm_uuid}"
  end

  def destroy_unused_credentials(authentication_mode, user); end

  def get_sm_records(user_id=nil, experiment_id=nil, params={})
    query = {}

    if params and params.include? 'states_not'
      if params['states_not'].kind_of? String
        query.merge!({state: {'$ne' => params['states_not'].to_sym}})
      elsif params['states_not'].kind_of? Array
        query.merge!({state: {'$nin' => params['states_not'].map{|i| i.to_sym}}})
      end
    elsif params and params.include? 'states'
      if params['states'].kind_of? String
        query.merge!({state: {'$eq' => params['states'].to_sym}})
      elsif params['states'].kind_of? Array
        query.merge!({state: {'$in' => params['states'].map{|i| i.to_sym}}})
      end
    end

    if params and params.include? 'onsite_monitoring'
      if !!params['onsite_monitoring']
        query.merge!({onsite_monitoring: {'$eq' => true}})
      else
        query.merge!({onsite_monitoring: {'$ne' => true}})
      end
    end
    query.merge!({user_id: user_id}) if user_id
    query.merge!({experiment_id: experiment_id}) if experiment_id
    _get_sm_records(query, params)
  end


  private :create_simulation_manager, :init_resources, :clean_up_resources
end
