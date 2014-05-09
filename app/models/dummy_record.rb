# Class used for various tests
# Specific attributes:
# - res_id
class DummyRecord < MongoActiveRecord
  include SimulationManagerRecord

  def self.collection_name
    'dummy_records'
  end

  def resource_id
    res_id
  end
end