class SupervisedExperiment < CustomPointsExperiment

  def init_empty(simulation)
    super simulation
    self.supervised = true
    self.completed = false
    self.result = {}
  end

  def start_supervisor_script(supervisor_script_id, script_params, experiment_input)
    script_params['experiment_id'] = self.id.to_s
    self.supervisor_script_uuid = SecureRandom.uuid
    password = SimulationManagerTempPassword.create_new_password_for self.supervisor_script_uuid, self.id
    script_params['user'] = self.supervisor_script_uuid
    script_params['password'] = password.password
    script_params['address'] = 'https://localhost:3001' #TODO ???

    res = nil
    begin
      res = RestClient.post( 'http://localhost:13337/start_supervisor_script',  id: supervisor_script_id,
                                                                          config: script_params.to_json,
                                                                          experiment_input: experiment_input
      )
      res = Utils::parse_json_if_string res
    rescue Exception => e
      res = {status: 'error', reason: e.to_s}
    end
    res
  end

  def mark_as_complete!(result)
    self.result = result
    self.completed = true
    # TODO cleanup and destroy temp password
  end

  def completed?
    self.completed
  end

end