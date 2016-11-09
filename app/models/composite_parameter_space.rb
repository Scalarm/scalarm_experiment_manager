class CompositeParameterSpace < ParameterSpace

  def initialize(*parameter_spaces)
    @inner_spaces = parameter_spaces
  end

  def size
    @inner_spaces.reduce(0){ |acc, space| acc + space.size }
  end

  def point(point_index)
    @inner_spaces.each do |space|
      if space.size >= point_index
        return space.point(point_index)
      else
        point_index -= space.size
      end
    end
  end

end