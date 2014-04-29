module SimulationManagerRecord
  def initialize(attributes)
    time = Time.now
    super(attributes.merge(sm_initialized_at: time, created_at: time, sm_initialized: false))
  end

  # Time to wait for resource initialization - after that, VM will be reinitialized
  # @return [Fixnum] time in seconds
  def max_init_time
    self.time_limit.to_i.minutes > 72.hours ? 40.minutes : 20.minutes
  end

  def to_h
    super.merge({ name: self.resource_id })
  end

  def to_json
    to_h.to_json
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
    (not self.sm_initialized) and (self.sm_initialized_at + self.max_init_time < Time.now)
  end

  def should_destroy?
    time_limit_exceeded? or time_limit_exceeded?
  end

end