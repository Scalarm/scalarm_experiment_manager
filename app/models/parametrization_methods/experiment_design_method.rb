class ExperimentDesignMethod
  attr_reader :parameters

  def initialize
    @parameters = []
  end

  def include_parameter(parameter)
    @parameters << parameter
  end

  def ==(another_design)
    another_design.kind_of?(self.class) and (@parameters == another_design.parameters)
  end
end