require 'infrastructure_facades/infrastructure_task_logger'

class SimulationManager
  attr_reader :record
  attr_reader :infrastructure
  attr_reader :logger

  def initialize(record, infrastructure)
    @record = record
    @infrastructure = infrastructure
    @logger = InfrastructureTaskLogger.new(infrastructure.short_name, record.resource_id)
  end

  # A human-readable Simulation Manager resource name, e.g. id of VM
  def name
    record.resource_id
  end

  def monitoring_cases
    {
      time_limit: {
          condition: lambda {record.time_limit_exceeded?},
          message: 'This Simulation Manager is going to be destroyed due to time limit',
          action: lambda {
            stop(record)
            record.destroy
          }
      },
      experiment_end: {
          condition: lambda {record.experiment_end?},
          message: 'This Simulation Manager will be destroyed due to experiment finishing',
          action: lambda {
            stop(record)
            record.destroy
          }
      },
      init_time_exceeded: {
          condition: lambda {record.init_time_exceeded?},
          message: "Initialization time (#{record.max_init_time.minutes} min) exceeded - discontinuing initialization",
          action: lambda {record_init_time_exceeded}
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

  def monitoring_order
    [:time_limit, :experiment_end, :init_time_exceeded, :sm_terminated, :try_to_initialize_sm]
  end

  def monitor
    monitoring_order.each do |c| monitoring_cases[c]
      m = monitoring_cases[c]
      begin
        if m[:condition].()
          log.info m[:message]
          m[:action].()
          break
        end
      rescue Exception => e
        logger.error "Exception on monitoring case #{c.to_s}: #{e.to_s}\n#{e.backtrace}"
      end
    end
  end

  DELEGATES = %w(stop restart status running? get_log install)

  def method_missing(m, *args, &block)
    if DELEGATES.include? m.to_s
      infrastructure.send("simulation_manager_#{m}", record)
    else
      super(m, *args, &block)
    end
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
    record.error = t('initialization_time_exceeded')
    record.save
  end

  def record_sm_failed
    record.error = t('simulation_manager_terminated')
    record.error_log = get_log
    record.save
  end

end