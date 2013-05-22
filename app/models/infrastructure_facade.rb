require 'yaml'

class InfrastructureFacade

  class SpawnProxy
    include Spawn
  end

  def prepare_configuration_for_simulation_manager(sm_uuid, user, experiment_id)
    Dir.chdir('/tmp')
    FileUtils.cp_r(File.join(Rails.root, 'public', 'scalarm_simulation_manager'), "scalarm_simulation_manager_#{sm_uuid}")
    # prepare sm configuration
    # TODO experiment manager address from database
    sm_config = {
        experiment_manager_address: '149.156.10.250',
        experiment_manager_user: ApplicationController::USER,
        experiment_manager_pass: ApplicationController::PASSWORD,

        experiment_id: experiment_id,
        user_id: user.id,
    }
    # adding information about storage manager from a config file
    config = YAML::load_file(File.join(Rails.root, 'config', 'scalarm_experiment_manager.yml'))
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
        plgrid: { label: 'PL-Grid', facade: PLGridFacade.new }
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