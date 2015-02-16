class SupervisedExperiment < CustomPointsExperiment

  def init_empty(simulation)
    super simulation
    self.supervised = true
    self.completed = false
    self.result = {}
  end

  def start_supervisor_script(user, supervisor_script_id, supervisor_script_params)
    supervisor_script_params['experiment_id'] = self.id.to_s
    supervisor_script_params['user'] = 'plgmwrona' #TODO temp login?
    supervisor_script_params['password'] = 'ala' #TODO temp password?
    supervisor_script_params['address'] = 'https://localhost:3001' #TODO ???
    # TODO verify whether all params are present

    self.supervisor_script_config = "/tmp/supervisor_script_config_#{self.id.to_s}"
    File.open(self.supervisor_script_config, 'w+') {
        |file| file.write(supervisor_script_params.to_json)
    }
    self.supervisor_script_log = "log/supervisor_script_log_#{self.id.to_s}"
    # TODO use script id to chose proper optimization script (some hash map?)
    path = 'public/scalarm_supervisor_scrpits/simulated_annealing/anneal.py'
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
    # TODO cleanup
  end

  def completed?
    self.completed
  end

end