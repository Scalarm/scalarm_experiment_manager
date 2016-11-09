require_relative 'experiment_design_method'

class Design2k1Parametrization < ExperimentDesignMethod

  def size
    2**(parameters.size - 1)
  end

end