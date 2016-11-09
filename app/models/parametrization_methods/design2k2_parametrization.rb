require_relative 'experiment_design_method'

class Design2k2Parametrization < ExperimentDesignMethod

  def size
    2**(parameters.size - 2)
  end

end