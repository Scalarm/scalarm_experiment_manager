# Methods to implement in classes including/subclasses
# - sm_record(resource_id, user_id)
# - all_sm_records_for(user_id)
# - simulation_manager(resource_id, user_id): returns SimulationManager for given container-unique ID (eg. vm_id, job_id)
# - simulation_managers_for(user_id): returns array of specific SimulationManagers
# - long_name -> String
# - short_name -> String - used as container id

module SimulationManagersContainer
  TREE_SM_NODE = 'sm-node'

  # @return [Array<Hash>] collection of simulation managers tree nodes
  def sm_nodes(user_id)
    all_sm_records_for(user_id).map {|r| SimulationManagersContainer.to_hash(r) }
  end

  def self.to_hash(record)
    {
        name: record.resource_id,
        type: TREE_SM_NODE
    }
  end
end
