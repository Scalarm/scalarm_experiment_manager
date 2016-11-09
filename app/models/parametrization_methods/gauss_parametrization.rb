class GaussParametrization < Struct.new(:parameter, :mean, :variance)

  def size
    1
  end

end