class CompositeParameterSpace < ParameterSpace

  def initialize(*parameter_spaces)
    @inner_spaces = parameter_spaces
  end

  def size
    @inner_spaces.reduce(0){ |acc, space| acc + space.size }
  end

  def point(index)

  end

end