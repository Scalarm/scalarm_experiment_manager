class RangeParametrization < Struct.new(:parameter, :min, :max, :step)

  def size
    (min..max).step(step).size
  end

  def values
    (min..max).step(step).to_a
  end

  def parameters
    [ parameter ]
  end

end