class ParameterSpace < Struct.new(:sampling_methods, :replication_level)

  def initialize(sampling_methods = [], replication_level = 1)
    @sampling_methods = sampling_methods
    @replication_level = replication_level
    @parameter_restrictions = parameter_restrictions
  end

  def size
    @size ||= @replication_level * @sampling_methods.reduce(1) { |acc, method| acc * method.size }
  end

  def point(point_index)
    throw ArgumentError.new("Index out of bound - maximum index is #{size}") if point_index > size

    combination = []
    id_num = (point_index - 1) % (size / @replication_level)

    value_list.each_with_index do |param_values, index|
      current_index = id_num / multiply_list[index]
      combination[index] = param_values[current_index]

      id_num -= current_index * multiply_list[index]
    end

    point_parameters = parameters.flatten
    point_values = combination.flatten
    ParameterSpacePoint.new(Hash[*point_parameters.zip(point_values).flatten])
  end

  def points
    1.upto(size).map { |idx| point(idx) }
  end

  def +(another_space)
    CompositeParameterSpace.new(self, another_space)
  end

  def value_list
    @value_list ||= @sampling_methods.map do |sampling_method|
      sampling_method.values
    end
  end

  def multiply_list
    @multiply_list ||= begin
      multiply_list = Array.new(value_list.size)
      multiply_list[-1] = 1
      (multiply_list.size - 2).downto(0) do |index|
        multiply_list[index] = multiply_list[index + 1] * value_list[index + 1].size
      end

      multiply_list
    end
  end

  def parameters
    @parameters ||= @sampling_methods.map do |sampling_method|
      sampling_method.parameters
    end
  end

end