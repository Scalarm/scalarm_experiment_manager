class SingleValueParametrization < Struct.new(:parameter, :value)

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