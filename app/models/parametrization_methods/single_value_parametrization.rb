class SingleValueParametrization < Struct.new(:parameter, :value)

  def size
    1
  end

end