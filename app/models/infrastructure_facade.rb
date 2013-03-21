class InfrastructureFacade

  def prepare_configuration_for_simulation_manager(sm_uuid, user, experiment_id)
    Dir.chdir('/tmp')
    FileUtils.cp_r(File.join(Rails.root, 'public', 'scalarm_simulation_manager'), "scalarm_simulation_manager_#{sm_uuid}")
    # prepare sm configuration
    # TODO experiment manager address from database
    sm_config = {
        experiment_manager_address: '149.156.10.250:6001',
        experiment_manager_user: ApplicationController::USER,
        experiment_manager_pass: ApplicationController::PASSWORD,
        experiment_id: experiment_id,
        user_id: user.id,
    }

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

end