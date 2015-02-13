require 'set'
require 'infrastructure_facades/infrastructure_task_logger'
require_relative 'infrastructure_errors'

class SimulationManager
  extend Forwardable

  attr_reader :record
  attr_reader :infrastructure
  attr_reader :logger

  def_delegators :@record,
                 :state, :init_time_exceeded?, :experiment_end?,
                 :time_limit_exceeded?, :should_destroy?, :stopping_time_exceeded?

  def initialize(record, infrastructure)
    unless record.state == :error
      begin
        record.validate
      rescue InfrastructureErrors::InvalidCredentialsError, InfrastructureErrors::NoCredentialsError
        Rails.logger.warn "Record #{record.id} for infrastructure #{infrastructure.short_name} has invalid credentials"
        record.store_error('credentials')
      rescue Exception => error
        Rails.logger.warn "Record #{record.id} for infrastructure #{infrastructure.short_name} did not pass "/
                              "validation due to error: #{error.to_s}\n#{error.backtrace.join("\n")}"
        record.store_error('validation', error.to_s)
      end
    end

    @record = record
    @infrastructure = infrastructure
    @logger = InfrastructureTaskLogger.new(infrastructure.short_name, record.resource_id)
  end

  def self.all_resource_states
    @@all_resource_states = [
        :not_available,
        :available,
        :initializing,
        :ready,
        :running_sm,
        :released
    ]
  end

  def all_resource_states
    SimulationManager.all_resource_states
  end

  # Delegates set_state to record and if it is ERROR, tries to stop resource if it was acqured
  def set_state(state)
    stop if state == :error and [:initializing, :ready, :running_sm].include? resource_status
    record.set_state(state)
  end

  def monitoring_cases
    @monitoring_cases ||= generate_monitoring_cases
  end

  def monitoring_order
    @monitoring_order ||= monitoring_cases.keys
  end

  def generate_monitoring_cases
    {
        error_resource_status: {
            source_states: SimulationManagerRecord::POSSIBLE_STATES - [:error],
            target_state: :error,
            resource_status: [:error],
            effect: :store_error_resource_status,
            message: 'Resource has ERROR status - marking record as invalid'
        },
        experiment_end: {
            source_states: [:created, :initializing, :running],
            target_state: :terminating,
            effect: :stop,
            condition: :experiment_end?,
            message: 'Experiment finished - destroying Simulation Manager'
        },
        prepare_resource: {
            source_states: [:created],
            target_state: :initializing,
            resource_status: [:available],
            effect: :prepare_resource,
            message: 'Preparing resource for Simulation Manager installation'
        },
        init_time_exceeded: {
            source_states: [:initializing],
            target_state: :initializing,
            condition: :init_time_exceeded?,
            effect: :restart,
            message: 'Initialization time exceeded - trying to restart resource'
        },
        install: {
            source_states: [:initializing],
            target_state: :running,
            resource_status: [:ready],
            effect: :install,
            message: 'Simulation Manager will be installed on resource now'
        },
        detect_sm_started: {
            source_states: [:initializing],
            target_state: :running,
            resource_status: [:running_sm, :released],
            message: 'Detected that Simulation Manager is running'
        },
        running_time_limit_exceeded: {
            source_states: [:running],
            target_state: :terminating,
            condition: :time_limit_exceeded?,
            effect: :stop,
            message: 'Time limit exceeded - terminating'
        },
        terminated_untimely: {
            source_states: [:running],
            target_state: :error,
            resource_status: all_resource_states - [:running_sm],
            condition: :should_not_be_already_terminated?,
            effect: :store_terminated_error,
            message: 'Simulation Manager has been terminated untimely - setting to ERROR state'
        },
        not_started_time_limit: {
            source_states: [:created, :initializing],
            target_state: :error,
            resource_status: [:not_available, :available, :initializing],
            condition: :time_limit_exceeded?,
            effect: :store_not_started_error,
            message: 'Time limit exceeded, but Simulation Manager was never run - destroying Simulation Manager'
        },
        stopping_time_exceeded: {
            source_states: [:terminating],
            target_state: :terminating,
            resource_status: all_resource_states - [:released],
            condition: :stopping_time_exceeded?,
            effect: :stop,
            message: 'Forcing resource termination due to long time of waiting for stop'
        },
        terminated_successfully: {
            source_states: [:terminating],
            resource_status: [:available, :released],
            effect: :destroy_record,
            message: 'Resource has been terminated successfully - removing record'
        }
    }

  end

  def should_not_be_already_terminated?
    @record.experiment.has_simulations_to_run? and not should_destroy?
  end

  def store_terminated_error
    record.store_error('terminated', get_log)
    # NOTICE: stop will be invoked twice, because of set_state(:error) behaviour
    stop
  end

  def store_not_started_error
    record.store_error('not_started')
  end

  def store_error_resource_status
    # TODO get detailed resource status
    record.store_error('resource_error')
  end

  def destroy_record
    user = ScalarmUser.where(user_id: record.user_id).first

    record.destroy

    unless user.nil?
      user.destroy_unused_credentials
    end
  end

  # A human-readable Simulation Manager resource name, e.g. id of VM
  def name
    record.resource_id
  end

  def state_transition_for?(monitoring_case, resource_status)
    mc = monitoring_case
    mc[:source_states].include?(state) and
        (not mc[:resource_status] or mc[:resource_status].include?(resource_status)) and
        (not mc[:condition] or self.send(mc[:condition]))
  end

  def execute_effect_for(monitoring_case)
    send(monitoring_case[:effect]) if monitoring_case[:effect]
  end

  def change_state_for(monitoring_case)
    # a little hack to prevent escaping from ERROR state if it was set inside action
    target_state = (state == :error ? :error : monitoring_case[:target_state])
    set_state(target_state) if target_state
  end

  def print_message_for(monitoring_case)
    logger.info monitoring_case[:message] if monitoring_case[:message]
  end

  def try_all_monitoring_cases
    cached_resource_status = resource_status
    logger.info "State: #{state}, Resource status: #{cached_resource_status}"

    monitoring_order.each do |case_name|
      monitoring_case = monitoring_cases[case_name]

      begin
        if state_transition_for?(monitoring_case, cached_resource_status)
          logger.debug "Monitoring case: #{case_name}"
          print_message_for(monitoring_case)
          execute_effect_for(monitoring_case)
          change_state_for(monitoring_case)
          break # at most one action from all actions should be taken
        end
      rescue Exception => e
        logger.error "Exception on monitoring case #{case_name.to_s}: #{e.to_s}\n#{e.backtrace.join("\n")}"
        begin
          if record.should_destroy?
            logger.warn 'Simulation manager is going to be destroyed'
            record.store_error('monitoring', "Exception on monitoring (#{case_name.to_s}): #{e.to_s}\n#{record.error_log}")
            stop
          end
        rescue Exception => de
          logger.error "Simulation manager cannot be terminated due to error: #{de.to_s}\n#{de.backtrace.join("\n")}"
          logger.error 'Please check if corresponding resource is terminated!'
        end
      end
    end
  end

  def monitor
    if not record.experiment
      logger.warn 'Forcing removing record, because experiment does not exists'
      stop_and_destroy(false)
    elsif state == :error
      logger.debug 'Has error flag - skipping'
    else
      begin
        before_monitor(record)
        try_all_monitoring_cases
        after_monitor(record)
        record.clear_no_credentials
      rescue InfrastructureErrors::NoCredentialsError => no_creds_error
        logger.info 'Lack of credentials'
        record.store_no_credentials
      end
    end
  end

  # Not using via Delegator extend, because these methods are wrapped into rescue block
  DELEGATES = %w(stop restart resource_status get_log prepare_resource install before_monitor after_monitor).to_set

  # return values of simulation manager action invoked on record with invalid credentials state
  ERROR_DELEGATES = {
      resource_status: :no_connection,
      running?: false,
      get_log: ''
  }

  def method_missing(m, *args, &block)
    action_name = m.to_s
    if DELEGATES.include? action_name
      begin
        infrastructure_action(action_name)
      rescue InfrastructureErrors::NoCredentialsError
        raise
      rescue Exception => e
        logger.warn "Exception on action #{action_name}: #{e.to_s}\n#{e.backtrace.join("\n")}"
        record.store_error('resource_action', "#{action_name}: #{e.to_s}")
        infrastructure_action('stop') rescue nil
      end
    else
      super(m, *args, &block)
    end
  end

  def infrastructure_action(action_name)
    begin
      # if the error cause is missing or invalid credentials - prevent to perform actions (to protect from authorization errors)
      if record.error == 'credentials'
        logger.warn "Simulation Manager action #{action_name} executed with invalid credentials - it will have no effect"
        ERROR_DELEGATES[action_name.to_sym]
      else
        result = (general_action(action_name) or delegate_to_infrastructure(action_name))
        # NOTICE: terminating state is set twice if stop was invoked from monitoring case
        set_state(:terminating) if action_name == 'stop'
        result
      end
    rescue InfrastructureErrors::NoCredentialsError => e
      logger.warn "No credentials exception on action #{action_name}: #{e.to_s}\n#{e.backtrace.join("\n")}"
      record.store_no_credentials
      raise
    end
  end

  # NOTE: all actions invoked here must be != false/nil
  def general_action(action_name)
    if action_name == 'resource_status' and record.onsite_monitoring
      stat = record.resource_status
      stat.nil? ? :not_available : stat
    else
      nil
    end
  end

  def delegate_to_infrastructure(action_name)
    infrastructure.send("_simulation_manager_#{action_name}", record)
  end

  def respond_to_missing?(m, include_all=false)
    DELEGATES.include? m.to_s
  end

  def stop_and_destroy(leave_on_error=true)
    begin
      stop
    ensure
      record.destroy unless leave_on_error and state == :error
    end
  end

end