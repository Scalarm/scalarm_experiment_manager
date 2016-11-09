class UniformParametrization < Struct.new(:parameter, :min, :max)

  def size
    1
  end
  
end