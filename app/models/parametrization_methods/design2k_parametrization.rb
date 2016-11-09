require_relative 'experiment_design_method'

class Design2kParametrization < ExperimentDesignMethod

  def size
    2**parameters.size
  end

  def points

  end

end