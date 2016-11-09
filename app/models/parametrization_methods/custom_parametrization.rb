class CustomParametrization < Struct.new(:parameter, :custom_values)

  def size
    custom_values.size
  end

end