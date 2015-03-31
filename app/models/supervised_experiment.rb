class SupervisedExperiment < CustomPointsExperiment

  def init_empty(simulation)
    super simulation
    self.supervised = true
    self.completed = false
    self.result = {}
  end

  def start_supervisor_script(simulation_id, supervisor_script_id, script_params)
    script_params['experiment_id'] = self.id.to_s
    self.supervisor_script_uuid = SecureRandom.uuid
    password = SimulationManagerTempPassword.create_new_password_for self.supervisor_script_uuid, self.id
    script_params['user'] = self.supervisor_script_uuid
    script_params['password'] = password.password

    script_params['lower_limit'] = []
    script_params['upper_limit'] = []
    script_params['parameters_ids'] = []

    Simulation.find_by_id(simulation_id).input_specification.each do |category|
      category['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          script_params['lower_limit'].append parameter['min']
          script_params['upper_limit'].append parameter['max']
          script_params['parameters_ids'].append Experiment.parameter_uid(category, entity, parameter)
        end
      end
    end
    if script_params['start_point'].nil?
      script_params['start_point'] = []
      script_params['lower_limit'].zip(script_params['upper_limit']).each do |e|
        # TODO string params
        script_params['start_point'].append((e[0]+e[1])/2)
      end
    end

    res = nil
    puts script_params.to_json

    begin
      res = RestClient.post( 'http://localhost:13337/start_supervisor_script',  script_id: supervisor_script_id,
                                                                          config: script_params.to_json)
      res = Utils::parse_json_if_string res
    rescue Exception => e
      res = {'status' => 'error', 'reason' => e.to_s}
    end
    res
  end

  def mark_as_complete!(results)
    self.results = results
    self.completed = true
    # TODO cleanup and destroy temp password
  end

  def completed?
    self.completed
  end

end