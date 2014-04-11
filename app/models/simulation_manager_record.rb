module SimulationManagerRecord
  # time to wait to VM initialization - after that, VM will be reinitialized [minutes object]
  def max_init_time
    self.time_limit.to_i.minutes > 72.hours ? 40.minutes : 20.minutes
  end

  def to_hash
    {
        name: self.resource_id,
        type: TreeUtils::TREE_SM_NODE,
        record_id: self.id.to_s,
        infrastructure_params: hash_params
    }
  end

  def hash_params
    {}
  end

  def experiment
    @experiment ||= Experiment.find_by_id(self.experiment_id)
  end

  def experiment_end?
    experiment.nil? or
        (experiment.is_running == false) or
        (experiment.experiment_size == experiment.get_statistics[2])
  end

  def time_limit_exceeded?
    self.created_at + self.time_limit.to_i.minutes < Time.now
  end

  def init_time_exceeded?
    (not self.sm_initialized) and (self.created_at + self.max_init_time < Time.now)
  end
end