class UniformParametrization < Struct.new(:parameter, :min, :max)

  def size
    1
  end

  def values
    [ value ]
  end

  def parameters
    [ parameter ]
  end
  
end