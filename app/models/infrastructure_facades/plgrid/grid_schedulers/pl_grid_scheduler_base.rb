# Subclasses must implement:
# - short_name() -> String
# - long_name() -> String

require 'infrastructure_facades/plgrid/pl_grid_simulation_manager'

class PLGridSchedulerBase
  include SimulationManagersContainer

  def scheduled_jobs(user_id)
    jobs = PlGridJob.find_all_by_query('scheduler_type'=>short_name, 'user_id'=>user_id)
    credentials = GridCredentials.find_by_user_id(user_id)
    credentials.nil? ? [] : jobs.map { |r| PlGridSimulationManager.new(r, credentials) }
  end

end