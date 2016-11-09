class CustomParametrization < Struct.new(:parameter, :custom_values)

  def size
    custom_values.size
  end

  def values
    custom_values
  end

  def parameters
    [ parameter ]
  end

end