require 'infrastructure_facades/simulation_manager'

class PlGridSimulationManager < SimulationManager
  def generate_monitoring_cases
    super().merge({
      plgrid_max_time_exceeded: {
          condition: lambda {record.max_time_exceeded?},
          message: 'Max time of running task in queue exceeded - restarting job',
          action: lambda {restart}
      },
      dectect_initialization: {
          condition: lambda {task_start_detected_first_time?},
          message: 'This job has been started',
          action: lambda {
            record.sm_initialized = true
            record.save
          }
      }
    })
  end

  def monitoring_order
    @monitoring_order ||= [:time_limit, :experiment_end, :init_time_exceeded,
                           :dectect_initialization, :sm_terminated, :plgrid_max_time_exceeded]
  end

  def task_start_detected_first_time?
    not record.sm_initialized and resource_status != :initializing
  end
end