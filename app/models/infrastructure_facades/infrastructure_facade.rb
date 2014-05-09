require 'yaml'

require_relative 'infrastructure_task_logger'
require_relative 'tree_utils'
require_relative 'infrastructure_errors'
require_relative 'simulation_manager'
require_relative 'clouds/cloud_factory'

require 'thread_pool'

# Methods necessary to implement by subclasses
# monitoring_loop() - a background job which will be executed periodically, monitors scheduled jobs/vms etc.
#   and handle their state, e.g. restart if necessary or delete db information. For one infrastructure type, they are
#   mutually excluded.
# default_additional_params() - a default list of any additional parameters necessary to start Simulation Managers with the facade
# start_simulation_managers(user, job_counter, experiment_id, additional_params) - starting jobs/vms with Simulation Managers
# clean_tmp_credentials(user_id, session) - remove from the session any credentials related to this infrastructure type
# get_running_simulation_managers(user, experiment = nil) - get a list of objects represented jobs/vms at this infrastructure
# current_state(user) - returns a string describing summary of current infrastructure state
# add_credentials(user, params, session) - save credentials to database or session based on request parameters
# short_name - short name of infrastructure, e.g. 'plgrid'
#
# SimulationManager delegate methods to implement
# - _simulation_manager_stop(record)
# - _simulation_manager_restart(record)
# - _simulation_manager_resource_status(record)
# - _simulation_manager_running?(record)
# - _simulation_manager_get_log(record)
# - _simulation_manager_install(record)

class InfrastructureFacade
  include InfrastructureErrors

  attr_reader :logger

  def initialize
    @logger = InfrastructureTaskLogger.new short_name
  end

  def self.prepare_configuration_for_simulation_manager(sm_uuid, user_id, experiment_id, start_at = '')
    Rails.logger.debug "Preparing configuration for Simulation Manager with id: #{sm_uuid}"

    Dir.chdir('/tmp')
    FileUtils.cp_r(File.join(Rails.root, 'public', 'scalarm_simulation_manager'), "scalarm_simulation_manager_#{sm_uuid}")
    # prepare sm configuration
    temp_password = SimulationManagerTempPassword.find_by_sm_uuid(sm_uuid)
    temp_password = SimulationManagerTempPassword.create_new_password_for(sm_uuid, experiment_id) if temp_password.nil?

    config = YAML::load_file File.join(Rails.root, 'config', 'scalarm.yml')
    sm_config = {
        experiment_id: experiment_id,
        #user_id: user_id,
        information_service_url: config['information_service_url'],
        experiment_manager_user: temp_password.sm_uuid,
        experiment_manager_pass: temp_password.password,
    }

    if start_at != ''
      sm_config['start_at'] = Time.parse(start_at)
    end

    IO.write("/tmp/scalarm_simulation_manager_#{sm_uuid}/config.json", sm_config.to_json)
    # zip all files
    %x[zip /tmp/scalarm_simulation_manager_#{sm_uuid}.zip scalarm_simulation_manager_#{sm_uuid}/*]
    Dir.chdir(Rails.root)
  end

  def self.get_facade_for(infrastructure_name)
    raise InfrastructureErrors::NoSuchInfrastructureError.new(infrastructure_name) if infrastructure_name.nil?
    info = get_registered_infrastructures[infrastructure_name.to_sym]
    raise InfrastructureErrors::NoSuchInfrastructureError.new(infrastructure_name) if info.nil? or not info.has_key? :facade
    info[:facade]
  end

  # returns a map of all supported infrastructures
  # infrastructure_id => {label: long_name, facade: facade_instance}
  def self.get_registered_infrastructures
    non_cloud_infrastructures.merge(cloud_infrastructures)
  end

  def self.non_cloud_infrastructures
    {
        plgrid: { label: 'PL-Grid', facade: PlGridFacade.new },
        private_machine: { label: 'Private resources', facade: PrivateMachineFacade.new }
    }
  end

  def self.cloud_infrastructures
    CloudFactory.infrastructures_hash
  end

  def monitoring_thread
    configure_polling_interval
    lock = MongoLock.new(short_name)
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

  def self.start_all_monitoring_threads
    get_registered_infrastructures.each do |infrastructure_id, infrastructure_information|
      Rails.logger.info("Starting monitoring thread of '#{infrastructure_id}'")

      Thread.new do
        infrastructure_information[:facade].monitoring_thread
      end
    end
  end

  def self.schedule_simulation_managers(user, experiment_id, infrastructure_type, job_counter, additional_params = nil)
    infrastructure = InfrastructureFacade.get_facade_for(infrastructure_type)
    additional_params = additional_params || infrastructure.default_additional_params

    status, response_msg = infrastructure.start_simulation_managers(user, job_counter, experiment_id, additional_params)

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
      create_simulation_manager(record)
    ensure
      clean_up_resources
    end
  end

  # This method ensures that resources used by SM will be cleaned up
  def yield_simulation_managers(*args, &block)
    begin
      init_resources
      yield get_sm_records(*args).map {|r| create_simulation_manager(r)}
    ensure
      clean_up_resources
    end
  end

  # This method ensures that resources used by SM will be cleaned up
  def yield_grouped_simulation_managers(*args, &block)
    begin
      init_resources
      yield Hash[get_grouped_sm_records(*args).map do |group, records|
        [group, records.map {|r| create_simulation_manager(r)}]
      end]
    ensure
      clean_up_resources
    end
  end

  # Used mainly to create node or subtree:
  # - if there is only one ScheduledJobContainer, creates node
  # - otherwise creates subtree with infrastructure as root and other ScheduledJobContainers as children
  # @return [Hash] node (or subtree) for infrastructure in infrastructure tree
  def to_h
    {
        name: long_name,
        infrastructure_name: short_name
    }
  end

  # Helper for Infrastrucutres Tree
  def sm_record_hashes(user_id, experiment_id=nil, params={})
    get_sm_records(user_id, experiment_id, params).map {|r| r.to_h }
  end

  # -- SimulationManger delegation default implementation --

  def _simulation_manager_before_monitor(record); end
  def _simulation_manager_after_monitor(record); end

  private

  def create_simulation_manager(record)
    SimulationManager.new(record, self)
  end

  def init_resources; end
  def clean_up_resources; end

end
