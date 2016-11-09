class ExperimentDesignMethod
  attr_reader :parameters, :raw_elements

  def initialize
    @parameters = []
    @raw_elements = []
  end

  def include_parameter(parameter, raw_element)
    @parameters << parameter
    @raw_elements << raw_element
  end

  def ==(another_design)
    another_design.kind_of?(self.class) and (@parameters == another_design.parameters)
  end
end