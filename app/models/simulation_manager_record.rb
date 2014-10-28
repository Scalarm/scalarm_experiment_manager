# Specific SimulationManagerRecords should have attributes:
#
# - user_id => integer - the user who scheduled this job - mongoid in the future
# - experiment_id => the experiment which should be computed by this job
# -* created_at => time - when this job were scheduled
# -* sm_initialized_at => time - last time when simulation manager of this job was started or restarted
# - time_limit => time - when this job should be stopped - in minutes
# - sm_uuid => string - uuid of configuration files
# -* sm_initialized => boolean - whether or not SM code has been sent to this machine
# - is_terminating => boolean - whether this SM with its resource should be terminated (stop action was invoked)
# - infrastructure_side_monitoring => boolean - whether this record should be supported by onsite-monitoring
#
# Fields with * can be initialized with initialize_fields method after creation.
#
# Subclasses should have methods:
# - resource_id() -> returns short description of resource, e.g. VM id
# - has_valid_credentials? -> returns false if corresponding credentials have invalid flag
#   - please do not check credentials here


module SimulationManagerRecord
  include MongoActiveRecordUtils

  POSSIBLE_STATES = [:created, :initializing, :running, :terminating, :error]

  attr_join :user, ScalarmUser
  attr_join :experiment, Experiment

  def initialize_fields
    set_state(:created)
  end

  # Backward compatibile method - using old data from database if "state" field is not found
  def state
    state_value = method_missing(:state)

    state_value and state_value.to_sym or old_state
  end

  def old_state
    (self.error and :error) or (self.is_terminating and :terminating) or (self.sm_initialized and :running) or
        :created
  end

  def state=(state)
    set_state(state)
  end

  def set_state(state)
    case state
      when :created
        self.created_at = self.sm_initialized_at = Time.now
      when :initializing
        self.sm_initialized_at = Time.now
      when :running
        # pass
      when :terminating
        self.stopped_at = Time.now
      when :error
        self.store_error('unknown') unless self.error
      else
        raise StandardError.new "Unknown state to set: #{state}"
    end

    set_attribute('state', state)
    save
  end

  # Time to wait for resource initialization - after that, VM will be reinitialized
  # @return [Fixnum] time in seconds
  def max_init_time
    self.time_limit.to_i.minutes > 72.hours ? 40.minutes : 20.minutes
  end

  def to_h
    h = super.merge(name: (self.resource_id or '...'))
    h.has_key?('state') and h or h.merge(state: self.state.to_s)
  end

  def to_json
    to_h.to_json
  end

  def experiment_end?
    experiment.nil? or experiment.end?
  end

  def time_limit_exceeded?
    self.created_at + self.time_limit.to_i.minutes < Time.now
  end

  def init_time_exceeded?
    self.state == :initializing and (self.sm_initialized_at + self.max_init_time < Time.now)
  end

  def stopping_time_exceeded?
    Time.now > self.stopped_at + 2.minutes
  end

  def should_destroy?
    (time_limit_exceeded? or experiment_end?) and record.state != :error
  end

  # Should be overriden
  def monitoring_group
    self.user_id
  end

  def store_error(error, error_log=nil)
    set_attribute('state', :error)
    self.error = error
    self.error_log = error_log if error_log
    self.save_if_exists

    user.destroy_unused_credentials
  end

  def store_no_credentials
    unless self.no_credentials
      self.set_attribute('no_credentials', true)
      self.save_if_exists
    end
  end

  def clear_no_credentials
    if self.no_credentials
      self.set_attribute('no_credentials', nil)
      self.save_if_exists
    end
  end

end