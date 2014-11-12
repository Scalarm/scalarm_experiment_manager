# Class used for recording information about independent Simulation Managers
class IndependentRecord < MongoActiveRecord
  include SimulationManagerRecord

  def self.collection_name
    'independent_records'
  end

  def resource_id
    sm_uuid
  end
end