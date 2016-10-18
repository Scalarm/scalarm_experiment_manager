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
# - onsite_monitoring => boolean - whether this record should be supported by onsite-monitoring
#
# Fields with * can be initialized with initialize_fields method after creation.
#
# Subclasses should have methods:
# - resource_id() -> returns short description of resource, e.g. VM id
# - has_valid_credentials? -> returns false if corresponding credentials have invalid flag
#   - please do not check credentials here
# - infrastructure_name -> String, short name of infrastructure

require 'mongo_lock'

require 'scalarm/database/core'

# TODO: move to scalarm-database?
module SimulationManagerRecord
  include Scalarm::Database::MongoActiveRecordUtils

  POSSIBLE_STATES = [:created, :initializing, :running, :terminating, :error]
  CMD_SEPARATOR = '#_#'

  attr_join :user, ScalarmUser

  def experiment
    e = Experiment.where(id: self.experiment_id).first
    e.nil? ? nil : e.auto_convert
  end

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

  def infrastructure
    attributes['infrastructure'] || self.infrastructure_name
  end

  def to_h
    h = super.merge(name: (self.resource_id or '...'))
    h['state'] = self.state.to_s unless h.has_key?('state')
    h['infrastructure'] = infrastructure unless h.has_key?('infrastructure')

    h
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

  def time_limit_not_exceeded?
    self.created_at + self.time_limit.to_i.minutes > Time.now
  end

  def init_time_exceeded?
    self.state == :initializing and (self.sm_initialized_at + self.max_init_time < Time.now)
  end

  def stopping_time_exceeded?
    Time.now > self.stopped_at + 2.minutes
  end

  ##
  # If cmd_delegated_at has been set, check if it exceeded limit.
  # If cmd_delegated_at has not been set, return false.
  def cmd_delegation_time_exceeded?
    self.cmd_delegated_at.nil? or self.cmd_delegated_at + 3.minutes < Time.now
  end

  def on_site_creation_time_exceeded?
    self.created_at + 3.minutes < Time.now
  end

  # A special cases, when SiM should be destroyed regardless of its Simulation Run
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
    if error_log
      self.error_log =
          (self.error_log ? "#{self.error_log}\n\n#{error_log}" : error_log)
    end
    self.save_if_exists
    self.clean_up_database!

    user.destroy_unused_credentials
  end

  # Destroy temp password and rollback current simulation run
  def clean_up_database!
    destroy_temp_password!

    Scalarm::MongoLock.mutex("experiment-#{self.experiment_id}-simulation-complete") do
      rollback_current_simulation_run!
    end
  end

  def destroy_temp_password!
    tp = get_temp_password
    if tp
      tp.destroy
    else
      Rails.logger.warn("Cannot find TempPassword for SiM Record with sm_uuid: #{self.sm_uuid}, Experiment ID: #{self.experiment_id}")
    end
  end

  def rollback_current_simulation_run!
    get_current_simulation_run.try :rollback!
  end

  def get_temp_password
    SimulationManagerTempPassword.find_by_sm_uuid(self.sm_uuid)
  end

  def get_current_simulation_run
    if not experiment.nil? and not self.sm_uuid.nil?
      experiment.simulation_runs.
          where(is_done: false, to_sent: false, sm_uuid: self.sm_uuid).first
    end
  end

  ##
  # Override standard attribute execution with command append with "#_#" separator
  # This is because there is some code using cmd_to_execute= method multiple times in one action
  # cmd_to_execute should not be replaced with new values in this case, but new command should be append
  # What is more, cmd_to_execute is not normally replaced with new value in EM, but only by onsite monitoring
  # See more in SCAL-956 issue comments
  def cmd_to_execute=(cmd)
    if cmd.blank?
      attributes['cmd_to_execute'] = ''
    else
      if attributes['cmd_to_execute'].blank?
        attributes['cmd_to_execute'] = cmd
      else
        attributes['cmd_to_execute'] << "#{CMD_SEPARATOR}#{cmd}"
      end
    end
  end

  ##
  # Override standard attribute execution with command append with "#_#" separator
  # This is because there is some code using cmd_to_execute_code= method multiple times in one action
  # cmd_to_execute should not be replaced with new values in this case, but new command should be append
  # What is more, cmd_to_execute_code is not normally replaced with new value in EM, but only by onsite monitoring
  # See more in SCAL-956 issue comments
  def cmd_to_execute_code=(code)
    if code.blank?
      attributes['cmd_to_execute_code'] = ''
    else
      if attributes['cmd_to_execute_code'].blank?
        attributes['cmd_to_execute_code'] = code
      else
        attributes['cmd_to_execute_code'] << "#{CMD_SEPARATOR}#{code}"
      end
    end
  end

  ##
  # Determines if simulation manager should run more simulations
  # If attribute simulations_left is not set, returned value is always true
  def has_more_simulations_to_run?
    (self.simulations_left || Float::INFINITY) > 0
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

  def log_file_name
    SSHAccessedInfrastructure::ScalarmFileName.sim_log(sm_uuid)
  end

  def log_path
    absolute_log_path
  end

  def absolute_log_path
    SSHAccessedInfrastructure::RemoteAbsolutePath.sim_log(sm_uuid)
  end

end
