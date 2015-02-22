class SupervisedExperiment < CustomPointsExperiment

  def init_empty(simulation)
    super simulation
    self.supervised = true
    self.completed = false
    self.result = {}
  end

  def start_supervisor_script(user, supervisor_script_id, supervisor_script_params, experiment_input)
    supervisor_script_params['experiment_id'] = self.id.to_s
    self.supervisor_script_uuid = SecureRandom.uuid
    password = SimulationManagerTempPassword.create_new_password_for self.supervisor_script_uuid, self.id
    supervisor_script_params['user'] = self.supervisor_script_uuid
    supervisor_script_params['password'] = password.password
    supervisor_script_params['address'] = 'https://localhost:3001' #TODO ???

    supervisor_script_params['lower_limit'] = []
    supervisor_script_params['upper_limit'] = []
    supervisor_script_params['parameters_ids'] = []
    experiment_input.each do |category|
      category['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          supervisor_script_params['lower_limit'].append parameter['min']
          supervisor_script_params['upper_limit'].append parameter['max']
          supervisor_script_params['parameters_ids'].append "#{category['id']}___#{entity['id']}___#{parameter['id']}"
        end
      end
    end

    if supervisor_script_params['start_point'].nil?
      supervisor_script_params['start_point'] = []
      supervisor_script_params['lower_limit'].zip(supervisor_script_params['upper_limit']).each do |e|
        supervisor_script_params['start_point'].append((e[0]+e[1])/2)
      end
    end
    # TODO verify whether all params are present

    self.supervisor_script_config = "/tmp/supervisor_script_config_#{self.id.to_s}"
    File.open(self.supervisor_script_config, 'w+') {
        |file| file.write(supervisor_script_params.to_json)
    }
    self.supervisor_script_log = "log/supervisor_script_log_#{self.id.to_s}"
    # TODO use script id to chose proper optimization script (some hash map?)
    path = 'scalarm_supervisor_scrpits/simulated_annealing/anneal.py'
    pid = Process.spawn("python2 #{path} #{self.supervisor_script_config} > #{self.supervisor_script_log} 2>&1")
    Process.detach(pid)
    self.supervisor_script_pid = pid
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