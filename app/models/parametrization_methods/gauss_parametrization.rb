class GaussParametrization < Struct.new(:parameter, :mean, :variance)

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