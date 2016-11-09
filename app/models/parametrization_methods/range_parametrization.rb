class RangeParametrization < Struct.new(:parameter, :min, :max, :step)

  def size
    (min..max).step(step).size
  end

end