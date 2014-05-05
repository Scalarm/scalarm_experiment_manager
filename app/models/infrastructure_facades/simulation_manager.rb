require 'set'
require 'infrastructure_facades/infrastructure_task_logger'

class SimulationManager
  attr_reader :record
  attr_reader :infrastructure
  attr_reader :logger

  attr_reader :monitoring_order
  attr_reader :monitoring_cases

  def initialize(record, infrastructure)
    @record = record
    @infrastructure = infrastructure
    @logger = InfrastructureTaskLogger.new(infrastructure.short_name, record.resource_id)

    @monitoring_cases = generate_monitoring_cases
    @monitoring_order = [:time_limit, :experiment_end, :init_time_exceeded, :sm_terminated, :try_to_initialize_sm]
  end

  def generate_monitoring_cases
    {
        time_limit: {
            condition: lambda {record.time_limit_exceeded?},
            message: 'This Simulation Manager is going to be destroyed due to time limit',
            action: lambda {destroy_with_record}
        },
        experiment_end: {
            condition: lambda {record.experiment_end?},
            message: 'This Simulation Manager will be destroyed due to experiment finishing',
            action: lambda {destroy_with_record}
        },
        init_time_exceeded: {
            condition: lambda {record.init_time_exceeded?},
            message: "Initialization time (#{record.max_init_time/60} min) exceeded - discontinuing initialization",
            action: lambda {
              record_init_time_exceeded
              restart
            }
        },
        sm_terminated: {
            condition: lambda {sm_terminated?},
            message: 'Simulation Manager is terminated, but experiment has not been completed. Reporting error.',
            action: lambda {record_sm_failed}
        },
        try_to_initialize_sm: {
            condition: lambda {should_initialize_sm?},
            message: 'This machine is going to be initialized with Simulation Manager now',
            action: lambda {
              install(record)
              record.sm_initialized = true
              record.save
            }
        }
    }
  end

  # A human-readable Simulation Manager resource name, e.g. id of VM
  def name
    record.resource_id
  end

  def monitor
    logger.info 'checking'
    before_monitor(record)

    monitoring_order.each do |c|
      m = monitoring_cases[c]
      begin
        if m[:condition].()
          logger.info m[:message]
          m[:action].()
          break # at most one action from all actions should be taken
        end
      rescue Exception => e
        logger.error "Exception on monitoring case #{c.to_s}: #{e.to_s}\n#{e.backtrace.join("\n")}"
        begin
          if record.should_destroy?
            logger.warn 'Simulation manager is going to be destroyed'
            destroy_with_record
          end
        rescue Exception => de
          logger.error "Simulation manager cannot be terminated due to error: #{de.to_s}\n#{de.backtrace.join("\n")}"
          logger.error 'THIS RECORD WILL BE REMOVED - please check if corresponding resource is terminated'
          record.destroy
        end
      end
    end

    after_monitor(record)
  end

  DELEGATES = %w(stop restart running? get_log install before_monitor after_monitor).to_set

  def method_missing(m, *args, &block)
    if DELEGATES.include? m.to_s
      infrastructure.send("simulation_manager_#{m}", record)
    else
      super(m, *args, &block)
    end
  end

  def status
    record.error.nil? ? infrastructure.simulation_manager_status(record) : :error
  end

  def respond_to_missing?(m, include_all=false)
    DELEGATES.include? m.to_s
  end

  def sm_terminated?
    status == :running and record.sm_initialized and (not running?)
  end

  def should_initialize_sm?
    status == :running and (not record.sm_initialized)
  end

  def record_init_time_exceeded
    record.error = I18n.t('initialization_time_exceeded')
    record.sm_initialized_at = Time.now
    record.sm_initialized = true
    record.save
  end

  def record_sm_failed
    record.error = I18n.t('simulation_manager_terminated')
    record.error_log = get_log
    record.save
  end

  def destroy_with_record
    stop(record)
    record.destroy
  end

end