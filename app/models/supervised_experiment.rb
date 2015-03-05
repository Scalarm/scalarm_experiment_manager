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

    script_params['lower_limit'] = []
    script_params['upper_limit'] = []
    script_params['parameters_ids'] = []
    experiment_input.each do |category|
      category['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          script_params['lower_limit'].append parameter['min']
          script_params['upper_limit'].append parameter['max']
          script_params['parameters_ids'].append "#{category['id']}___#{entity['id']}___#{parameter['id']}"
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
    # TODO verify whether all params are present

    script_config = "/tmp/supervisor_script_config_#{self.id.to_s}"
    File.open(script_config, 'w+') {
        |file| file.write(script_params.to_json)
    }
    script_log = "log/supervisor_script_log_#{self.id.to_s}"
    # TODO use script id to chose proper optimization script (some hash map?)
    path = 'scalarm_supervisor_scrpits/simulated_annealing/anneal.py'
    pid = Process.spawn("python2 #{path} #{script_config}", out: script_log, err: script_log)
    Process.detach(pid)
    self.supervisor_script_pid = pid
    self.save
    pid
  end

  def set_result!(result)
    self.result = result
  end

  def mark_as_complete!
    self.completed = true
    # TODO cleanup and destroy temp password
  end

  def completed?
    self.completed
  end

end