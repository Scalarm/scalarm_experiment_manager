# Specific SimulationManagerRecords should have attributes:
#
# - user_id => integer - the user who scheduled this job - mongoid in the future
# - experiment_id => the experiment which should be computed by this job
# -* created_at => time - when this job were scheduled
# -* sm_initialized_at => time - when simulation manager of this job was initialized
# - time_limit => time - when this job should be stopped - in minutes
# - sm_uuid => string - uuid of configuration files
# -* sm_initialized => boolean - whether or not SM code has been sent to this machine
#
# Fields with * can be initialized with initialize_fields method after creation.
#
# Subclasses should have methods:
# - resource_id() -> returns short description of resource, e.g. VM id


module SimulationManagerRecord
  def initialize_fields
    self.created_at = self.sm_initialized_at = Time.now
    self.sm_initialized = false
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

  # Should be overriden
  def monitoring_group
    self.user_id
  end

end