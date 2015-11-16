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
        ## handle command delegation cases
        command_delegation_timeout: {
            source_states: SimulationManagerRecord::POSSIBLE_STATES,
            target_state: :error,
            condition: :on_site_cmd_timed_out?,
            effect: :error_cmd_delegation_timed_out,
            message: "Waiting for command execution in onsite monitoring timed out: #{@record.cmd_to_execute_code} -> #{@record.cmd_to_execute}"
        },
        created_on_site_timeout: {
            source_states: [:created],
            target_state: :error,
            condition: :on_site_creation_timed_out?,
            effect: :error_created_on_site_timed_out,
            message: 'Timeout on SiM initialization after creation with on-site monitoring'
        },
        waiting_for_command_delegation: {
            source_states: SimulationManagerRecord::POSSIBLE_STATES,
            condition: :cmd_delegated_on_site?,
            effect: :effect_pass,
            message: "Waiting for command to execute in WorkersManager: #{@record.cmd_to_execute_code}"
        },

        ## handling invalid states combinations
        resource_invalid_state_on_initializing: {
            source_states: [:initializing],
            target_state: :error,
            resource_status: [:not_available, :available],
            message: 'Resource status came back to too early state when SiM state is initializing'
        },
        resource_invalid_state_on_terminating: {
            source_states: [:terminating],
            target_state: :error,
            resource_status: [:not_available, :available, :initializing, :ready],
            message: 'Resource status came back to too early state when SiM state is terminating'
        },
        resource_reports_work_without_resource_id: {
            source_states: [:created],
            target_state: :error,
            resource_status: [:initializing, :ready, :running_sm, :released],
            message: 'Resource status is later than available, but state is created'
        },

        ## general cases
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
        no_more_simulation_runs: {
            source_states: [:created, :initializing, :running],
            target_state: :terminating,
            effect: :stop,
            condition: :no_pending_tasks?,
            message: 'There is no more simulation runs waiting - destroying Simulation Manager'
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
            condition: :should_be_running?,
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

  # This SiM is not computing any simulation run and we do not predict any
  # If the experiment is supervised, this method always returns true,
  # as it always can be more simulations to do
  def no_pending_tasks?
    if not @record.experiment.supervised
      simulation_run = record.experiment.simulation_runs.find_by_sm_uuid(record.sm_uuid)
      sr_is_running = (simulation_run and not simulation_run.to_sent and not simulation_run.is_done)
      not sr_is_running and not @record.experiment.has_simulations_to_run?
    else
      # we assume that in supervised experiment, there are always tasks pending
      false
    end
  end

  def should_be_running?
    not should_destroy?
  end

  ##
  # True if it is monitored by on-site monitoring
  def cmd_delegated_on_site?
    !!@record.onsite_monitoring and
        not @record.cmd_to_execute_code.blank? or not @record.cmd_to_execute.blank?
  end

  def on_site_creation_timed_out?
    !!@record.onsite_monitoring and @record.on_site_creation_time_exceeded?
  end

  def on_site_cmd_timed_out?
    cmd_delegated_on_site? and @record.cmd_delegation_time_exceeded?
  end

  def effect_pass
    # just passes - for testing purposes
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

  def error_created_on_site_timed_out
    record.store_error('on_site_not_responding', 'Simulation Manager start timeout')
  end

  def error_cmd_delegation_timed_out
    record.store_error('on_site_not_responding', "Execution timed out: #{@record.cmd_to_execute}")
  end

  def destroy_record
    user = ScalarmUser.where(user_id: record.user_id).first
    record.clean_up_database!
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
      rescue => e
        logger.error "Exception on monitoring case #{case_name.to_s}: #{e.to_s}\n#{e.backtrace.join("\n")}"
        begin
          if record.should_destroy?
            logger.warn 'Simulation manager is going to be destroyed'
            record.store_error('monitoring', "Exception on monitoring (#{case_name.to_s}): #{e.to_s}\n#{record.error_log}")
            stop
          end
        rescue => de
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
        general_result = general_action(action_name)
        general_result.nil? ? delegate_to_infrastructure(action_name) : general_result
      end
    rescue InfrastructureErrors::NoCredentialsError => e
      logger.warn "No credentials exception on action #{action_name}: #{e.to_s}\n#{e.backtrace.join("\n")}"
      record.store_no_credentials
      raise
    end
  end

  # Executes additional action before delegate_to_infrastructure for action_name
  # return nil to continue and delegate action to infrastructure
  # or return other value to stop execution
  def general_action(action_name)
    case action_name
      when 'resource_status'
        if record.onsite_monitoring
          record.resource_status || :not_available
        else
          nil
        end
      when 'stop'
        set_state(:terminating)
        @record.clean_up_database!
        nil
      when 'restart'
        @record.clean_up_database!
        nil
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