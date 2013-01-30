require "agent_parameter"

class AgentElement
  attr_accessor :id, :parameters, :type, :min, :max, :default, :label, :group_id

  def initialize
    @id = 0
    @parameters = []
    @name = nil
    @group_id = nil
  end

  def add_parameter(parameter_hash)
    @parameters << AgentParameter.new(self, parameter_hash)
  end

end
