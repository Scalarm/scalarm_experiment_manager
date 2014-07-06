require 'infrastructure_facades/simulation_manager'

class PlGridSimulationManager < SimulationManager
  def_delegators :record, :max_time_exceeded?

  def generate_monitoring_cases
    super.merge(
        plgrid_max_time_exceeded: {
            source_states: [:running],
            target_state: :initializing,
            effect: :restart,
            condition: :max_time_exceeded?,
            message: 'Restarting PL-Grid task due to long time running'
        }
    )
  end
end