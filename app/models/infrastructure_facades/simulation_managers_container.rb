# Methods to implement in classes including/subclasses
# - all_user_simulation_managers(user_id): returns array of specific SimulationManagers
# - simulation_manager(resource_id, user_id): returns SimulationManager for given container-unique ID (eg. vm_id, job_id)

module SimulationManagersContainer
  # @return [Array<Hash>] collection of simulation managers tree nodes
  def sm_nodes(user_id)
    all_user_sm_records(user_id).map {|r| SimulationManagersContainer.to_hash(r) }
  end

  def self.to_hash(record)
    {
        name: record.resource_id,
        type: 'sm-node'
    }
  end
end
