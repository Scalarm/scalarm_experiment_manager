class ParameterSpace

  def initialize(sampling_methods = {})
    @sampling_methods = sampling_methods

  # TODO calculate value list
  end

  def size
    return 0 if @sampling_methods.blank?

    @sampling_methods.reduce(1) { |acc, method| acc * method.size}
  end

  def point(index)

  end

  def +(another_space)
    CompositeParameterSpace.new(self, another_space)
  end

end