# Subclasses must implement:
# - short_name() -> String
# - long_name() -> String

require 'infrastructure_facades/plgrid/pl_grid_simulation_manager'

class PlGridSchedulerBase
  include SimulationManagersContainer

  def get_container_sm_record(id, params)
    PlGridJob.find_by_query({id: id, scheduler_type: short_name}.merge(params))
  end

  def get_container_all_sm_records(params)
    PlGridJob.find_all_by_query({scheduler_type: short_name}.merge(params))
  end

  def get_container_all_simulation_managers(params)
    jobs = get_all_container_sm_records(params)
    credentials = GridCredentials.find_by_user_id(params[:user_id])
    if credentials.nil?
      []
    else
      jobs.map { |r| PlGridSimulationManager.new(r) }
    end
  end

  def get_container_simulation_manager(id, params)
    job = get_container_sm_record(id, params)
    credentials = GridCredentials.find_by_user_id(user_id)
    credentials.nil? ? nil : PlGridSimulationManager.new(job)
  end

end