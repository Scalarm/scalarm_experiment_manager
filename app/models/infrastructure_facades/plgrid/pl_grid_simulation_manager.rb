require 'infrastructure_facades/simulation_manager'

class PlGridSimulationManager < SimulationManager
  def generate_monitoring_cases
    super().merge({
      plgrid_max_time_exceeded: {
          condition: lambda {record.max_time_exceeded?},
          message: 'Max time of running task in queue exceeded - restarting job',
          action: lambda {restart}
      }
    })
  end

  def monitoring_order
    super() + [:plgrid_max_time_exceeded]
  end
end