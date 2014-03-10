require 'yaml'

require 'clouds/cloud_factory'

# methods necessary to implement by subclasses
# start_monitoring() - starting a background job which monitors scheduled jobs/vms etc. and handle their state, e.g. restart if necessary or delete db information
# default_additional_params() - a default list of any additional parameters necessary to start Simulation Managers with the facade
# start_simulation_managers(user, job_counter, experiment_id, additional_params) - starting jobs/vms with Simulation Managers
# clean_tmp_credentials(user_id, session) - remove from the session any credentials related to this infrastructure type
# get_running_simulation_managers(user, experiment = nil) - get a list of objects represented jobs/vms at this infrastructure
# current_state(user) - returns a string describing summary of current infrastructure state
# add_credentials(user, params, session) - save credentials to database or session based on request parameters
# short_name - short name of infrastructure, e.g. 'plgrid'
# to_hash - hash representing subtree for Infrastructure view tree - array of {name: ..., chilrden: [...]}

class InfrastructureFacade

  attr_reader :logger

  def initialize
    @logger = InfrastructureTaskLogger.new short_name
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
        user_id: user_id,
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
        plgrid: { label: 'PL-Grid', facade: PlGridFacade.new }
    }
  end

  def self.cloud_infrastructures
    CloudFactory.infrastructures_hash
  end

  def self.start_monitoring
    get_registered_infrastructures.each do |infrastructure_id, infrastructure_information|
      Rails.logger.info("Starting monitoring thread of '#{infrastructure_id}'")

      Thread.new do
        infrastructure_information[:facade].start_monitoring
      end
    end
  end

  # Used mainly to create node or subtree:
  # - if there is only one ScheduledJobContainer, creates node
  # - otherwise creates subtree with infrastructure as root and other ScheduledJobContainers as children
  # @return [Hash] node (or subtree) for infrastructure in infrastructure tree
  def to_hash
    smc = sm_containers
    if smc.count == 1
      {
          name: smc[0].long_name,
          type: 'sm_containter',
          short: smc[0].short_name
      }
    else
      {
          name: self.long_name,
          type: 'meta_infrastructure',
          short: self.short_name,
          children: smc.map do |container|
            {
                name: container.long_name,
                type: 'sm_container',
                short: container.short_name
            }
          end
      }
    end
  end

  # Could be overriden in subclasses if there are many ScheduledJobsContainers for infrastructure.
  # By default, infrastructure is also a ScheduledJobsContainer (one node on tree).
  def sm_containers
    [self]
  end

  # @return [Array<SimulationManagersContainer>] scheduled jobs containers for all registered infrastructures
  def self.get_registered_sm_containters
    # FIXME - use classes not instances
    get_registered_infrastructures.values.map do |inf|
      Hash[inf[:facade].sm_containers.map {|container| [container.short_name, container]}]
    end.reduce :merge
  end

  def self.schedule_simulation_managers(user, experiment_id, infrastructure_type, job_counter, additional_params = nil)
    infrastructure = InfrastructureFacade.get_facade_for(infrastructure_type)
    additional_params = additional_params || infrastructure.default_additional_params

    status, response_msg = infrastructure.start_simulation_managers(user, job_counter, experiment_id, additional_params)

    render json: response_msg, status: status
  end

end

class InfrastructureTaskLogger
  def initialize(infrastructure_name, task_id=nil)
    if task_id
      @log_format = Proc.new do |message|
        "[#{infrastructure_name}][#{task_id.to_s}] #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{message}"
      end
    else
      @log_format = Proc.new do |message|
        "[#{infrastructure_name}] #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{message}"
      end
    end
  end

  def method_missing(method_name, *args, &block)
    if %w(info debug warn error).include? method_name.to_s
      Rails.logger.send(method_name.to_s, @log_format.call(args[0], block))
    else
      super(method_name, *args, &block)
    end
  end
end