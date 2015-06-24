# Class used for various tests
# Specific attributes:
# - res_id
require 'scalarm/database/model'

class DummyRecord < Scalarm::Database::Model::DummyRecord
  include SimulationManagerRecord

  def resource_id
    res_id
  end

  def infrastructure_name
    'dummy'
  end
end