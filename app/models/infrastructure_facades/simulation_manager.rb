class SimulationManager
  attr_reader :record
  attr_reader :infrastructure

  def initialize(record, infrastrcuture)
    @record = record
    @infrastructure = infrastrcuture
  end

  def name
    record.resource_id
  end
end