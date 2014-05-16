require 'set'
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

  def monitoring_cases
    @monitoring_cases ||= generate_monitoring_cases
  end

  def monitoring_order
    @monitoring_order ||= [:time_limit, :experiment_end, :init_time_exceeded, :sm_terminated, :try_to_initialize_sm]
  end

  def generate_monitoring_cases
    {
        time_limit: {
            condition: lambda {record.time_limit_exceeded?},
            message: 'Time limit exceeded - destroying Simulation Manager',
            action: lambda {
              record.store_error('not_started') if record.state == :before_init
              destroy_with_record
            }
        },
        experiment_end: {
            condition: lambda {record.experiment_end?},
            message: 'Experiment finished - destroying Simulation Manager',
            action: lambda {destroy_with_record}
        },
        init_time_exceeded: {
            condition: lambda {record.init_time_exceeded?},
            message: "Initialization time (#{record.max_init_time/60} min) exceeded - trying to restart resource",
            action: lambda {restart}
        },
        sm_terminated: {
            condition: lambda {sm_terminated?},
            message: 'Simulation Manager has been terminated untimely - setting to error state',
            action: lambda {record_sm_failed}
        },
        try_to_initialize_sm: {
            condition: lambda {should_initialize_sm?},
            message: 'Simulation Manager will be initialized now',
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
    if record.state == :error
      logger.info 'Has error flag - skipping'
    else
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
              record.store_error('monitoring', "Exception on monitoring (#{c.to_s}): #{e.to_s}\n#{record.error_log}")
              stop
            end
          rescue Exception => de
            logger.error "Simulation manager cannot be terminated due to error: #{de.to_s}\n#{de.backtrace.join("\n")}"
            logger.error 'Please check if corresponding resource is terminated!'
          end
        end
      end

      after_monitor(record)
    end
  end

  DELEGATES = %w(stop restart resource_status running? get_log install before_monitor after_monitor).to_set

  def method_missing(m, *args, &block)
    if DELEGATES.include? m.to_s
      begin
        infrastructure.send("_simulation_manager_#{m}", record)
      rescue Exception => e
        logger.warn "Exception on action #{m}: #{e.to_s}\n#{e.backtrace.join("\n")}"
        record.store_error('resource_action', "#{m}: #{e.to_s}")
        stop
      end
    else
      super(m, *args, &block)
    end
  end

  def respond_to_missing?(m, include_all=false)
    DELEGATES.include? m.to_s
  end

  def sm_terminated?
    # checks "should_destroy" one more time to be sure that experiment did not end in the meantime
    (record.state == :initialized) and (not running?) and (not record.should_destroy?)
  end

  def should_initialize_sm?
    (record.state == :before_init) and (resource_status == :running)
  end

  def record_sm_failed
    record.store_error('terminated', get_log)
    stop
  end

  def destroy_with_record
    begin
      stop
    ensure
      record.destroy unless record.state == :error
    end
  end

end