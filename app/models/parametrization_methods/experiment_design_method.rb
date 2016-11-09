class ExperimentDesignMethod
  attr_reader :parameters, :constraints

  def initialize(parameters = [], constraints = [])
    @parameters = parameters
    @constraints = constraints
  end

  def include_parameter(parameter, constraint)
    @parameters << parameter
    @constraints << constraint
  end

  def ==(another_design)
    another_design.kind_of?(self.class) and (@parameters == another_design.parameters) and (@constraints == another_design.constraints)
  end

  def size
    throw StandardError('Not implemented')
  end

  def values
    throw StandardError('Not implemented')
  end

  def parameters
    throw StandardError('Not implemented')
  end

end