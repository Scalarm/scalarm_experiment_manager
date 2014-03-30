require 'yaml'

require_relative 'infrastructure_task_logger'
require 'clouds/cloud_factory'

# Methods necessary to implement by subclasses
# - monitoring_loop() - a background job which will be executed periodically, monitors scheduled jobs/vms etc.
#     and handle their state, e.g. restart if necessary or delete db information. For one infrastructure type, they are
#     mutually excluded.
# - default_additional_params() - a default list of any additional parameters necessary to start Simulation Managers with the facade
# - start_simulation_managers(user, job_counter, experiment_id, additional_params) - starting jobs/vms with Simulation Managers
# - clean_tmp_credentials(user_id, session) - remove from the session any credentials related to this infrastructure type
# - get_facade_sm_records(user, experiment = nil) - get a list of objects represented jobs/vms at this infrastructure
# - get_facade_simulation_managers(user, experiment = nil) - get a list of objects represented jobs/vms at this infrastructure
# - current_state(user) - returns a string describing summary of current infrastructure state
# - add_credentials(user, params, session) - save credentials to database or session based on request parameters
# - short_name - short name of infrastructure, e.g. 'plgrid'
#
# Methods with default implementation, whose could be overriden:
# - to_hash - hash representing subtree for Infrastructure view tree - array of {name: ..., chilrden: [...]}
# - sm_containters - array with SimulationManagerContainers for this infrastructure
#     by default the only container is infrastructure itself

class InfrastructureFacade

  attr_reader :logger

  # -- Infrastructures tree constants

  TREE_SM_CONTAINER = 'sm-container-node'
  TREE_META = 'meta-node'


  # --

  def initialize
    @logger = InfrastructureTaskLogger.new short_name
    config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
    @polling_interval_sec = config.has_key?('monitoring') ? config['monitoring']['interval'].to_i : 60
    logger.debug "Setting polling interval to #{@polling_interval_sec} seconds"
  end

  def self.prepare_configuration_for_simulation_manager(sm_uuid, user_id, experiment_id, start_at = '')
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
    get_registered_infrastructures[infrastructure_name.to_sym][:facade]
  end

  # returns a map of all supported infrastructures
  # infrastructure_id => facade object
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

  def start_monitoring
    lock = MongoLock.new(short_name)
    while true do
      if lock.acquire
        begin
          logger.info 'monitoring thread is working'
          monitoring_loop
        rescue Exception => e
          logger.error "Monitoring exception: #{e.class}, #{e}\n#{e.backtrace.join("\n")}"
          # TODO: add 'clean_expired' method to each InfrastructureFacade to remove invalid outdated records
        end
        lock.release
      end
      sleep(@polling_interval_sec)
    end
  end

  def self.start_monitoring
    get_registered_infrastructures.each do |infrastructure_id, infrastructure_information|
      Rails.logger.info("Starting monitoring thread of '#{infrastructure_id}'")

      Thread.new do
        infrastructure_information[:facade].start_monitoring
      end
    end
  end

  def get_infrastructure_sm_records(user_id, experiment_id=nil)
    (get_sm_containers.map {|smc| smc.get_container_sm_records(user_id, experiment_id)}).flatten
  end

  def get_infrastructure_simulation_managers(user_id, experiment_id=nil)
    (get_sm_containers.map {|smc| smc.get_container_simulation_managers(user_id, experiment_id)}).flatten
  end

  # Used mainly to create node or subtree:
  # - if there is only one ScheduledJobContainer, creates node
  # - otherwise creates subtree with infrastructure as root and other ScheduledJobContainers as children
  # @return [Hash] node (or subtree) for infrastructure in infrastructure tree
  def to_hash
    smc = get_sm_containers
    if smc.count == 1
      {
          name: smc[0].long_name,
          type: TREE_SM_CONTAINER,
          short: smc[0].short_name
      }
    else
      {
          name: self.long_name,
          type: TREE_META,
          short: self.short_name,
          children: smc.map do |container|
            {
                name: container.long_name,
                type: TREE_SM_CONTAINER,
                short: container.short_name
            }
          end
      }
    end
  end

  # Could be overriden in subclasses if there are many ScheduledJobsContainers for infrastructure.
  # By default, infrastructure is also a ScheduledJobsContainer (one node on tree).
  def get_sm_containers
    [self]
  end

  # @return [Array<SimulationManagersContainer>] scheduled jobs containers for all registered infrastructures
  def self.get_registered_sm_containters
    get_registered_infrastructures.values.map do |inf|
      Hash[inf[:facade].get_sm_containers.map {|container| [container.short_name.to_sym, container]}]
    end.reduce :merge
  end

  def self.schedule_simulation_managers(user, experiment_id, infrastructure_type, job_counter, additional_params = nil)
    infrastructure = InfrastructureFacade.get_facade_for(infrastructure_type)
    additional_params = additional_params || infrastructure.default_additional_params

    status, response_msg = infrastructure.start_simulation_managers(user, job_counter, experiment_id, additional_params)

    render json: response_msg, status: status
  end

end
