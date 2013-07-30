require 'yaml'

# methods necessary to implement by subclasses
# start_monitoring() - starting a background job which monitors scheduled jobs/vms etc. and handle their state, e.g. restart if necessary or delete db information
# default_additional_params() - a default list of any additional parameters necessary to start Simulation Managers with the facade
# start_simulation_managers(user, job_counter, experiment_id, additional_params) - starting jobs/vms with Simulation Managers
# clean_tmp_credentials(user_id, session) - remove from the session any credentials related to this infrastructure type
# get_running_simulation_managers(user, experiment = nil) - get a list of objects represented jobs/vms at this infrastructure
# current_state(user) - returns a string describing summary of current infrastructure state
# add_credentials(user, params, session) - save credentials to database or session based on request parameters

class InfrastructureFacade

  class SpawnProxy
    include Spawn
  end

  def prepare_configuration_for_simulation_manager(sm_uuid, user_id, experiment_id)
    Dir.chdir('/tmp')
    FileUtils.cp_r(File.join(Rails.root, 'public', 'scalarm_simulation_manager'), "scalarm_simulation_manager_#{sm_uuid}")
    # prepare sm configuration
    temp_password = SimulationManagerTempPassword.create_new_password_for(sm_uuid)
    # TODO experiment manager address from database
    sm_config = {
        experiment_manager_address: 'system.scalarm.com',
        experiment_manager_user: temp_password.sm_uuid,
        experiment_manager_pass: temp_password.password,

        experiment_id: experiment_id,
        user_id: user_id,
    }

    config = YAML::load_file File.join(Rails.root, 'config', 'scalarm_experiment_manager.yml')
    # adding information about storage manager from a config file
    sm_config['storage_manager'] = config['storage_manager']

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
  # TODO should this be taken from a configuration file ?
  def self.get_registered_infrastructures
    {
        plgrid: { label: 'PL-Grid', facade: PLGridFacade.new },
        amazon: { label: 'Amazon Elastic Compute Cloud', facade: AmazonFacade.new }
    }
  end

  def self.start_monitoring
    get_registered_infrastructures.each do |infrastructure_id, infrastructure_information|
      Rails.logger.debug("Starting monitoring thread of '#{infrastructure_id}'")

      ActiveRecord::Base.connection.reconnect!
      SpawnProxy.new.spawn_block do
        infrastructure_information[:facade].start_monitoring
      end
      ActiveRecord::Base.connection.reconnect!
    end
  end

  def self.schedule_simulation_managers(user, experiment_id, infrastructure_type, job_counter, additional_params = nil)
    infrastructure = InfrastructureFacade.get_facade_for(infrastructure_type)
    additional_params = additional_params || infrastructure.default_additional_params

    status, response_msg = infrastructure.start_simulation_managers(user, job_counter, experiment_id, additional_params)

    return status, response_msg
  end

end