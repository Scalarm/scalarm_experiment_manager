require 'scalarm/database/model'

class DummyRecord < Scalarm::Database::Model::DummyRecord
  include SimulationManagerRecord

  def resource_id
    res_name
  end

  def infrastructure_name
    'dummy'
  end
end