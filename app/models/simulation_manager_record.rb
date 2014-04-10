module SimulationManagerRecord
  # time to wait to VM initialization - after that, VM will be reinitialized [minutes object]
  def max_init_time
    self.time_limit.to_i.minutes > 72.hours ? 40.minutes : 20.minutes
  end

  def to_hash
    {
        name: self.resource_id,
        type: TreeUtils::TREE_SM_NODE,
        record_id: self.id.to_s,
        infrastructure_params: hash_params
    }
  end

  def hash_params
    {}
  end
end