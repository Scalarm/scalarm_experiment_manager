# Methods to implement in classes including/subclasses
# - sm_record(resource_id, user_id)
# - all_sm_records_for(user_id)
# - simulation_manager(resource_id, user_id): returns SimulationManager for given container-unique ID (eg. vm_id, job_id)
# - simulation_managers_for(user_id): returns array of specific SimulationManagers
# - long_name -> String
# - short_name -> String - used as container id
require_relative 'tree_utils'

module SimulationManagersContainer
  # @return [Array<Hash>] collection of simulation managers tree nodes
  def sm_nodes(user_id)
    get_container_all_sm_records({user_id: user_id}).map {|r| SimulationManagersContainer.to_hash(r) }
  end

  def self.to_hash(record)
    {
        name: record.resource_id,
        type: TreeUtils::TREE_SM_NODE
    }
  end
end
