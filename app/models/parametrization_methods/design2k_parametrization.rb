require_relative 'experiment_design_method'

class Design2kParametrization < ExperimentDesignMethod

  def size
    2**@parameters.size
  end

  def values
    min_maxes = @constraints.map do |constraint|
      [ constraint.min, constraint.max ]
    end

    if min_maxes.size > 1
      min_maxes[1..-1].reduce(min_maxes.first) { |acc, values| acc.product values }.map { |x| x.flatten }
    else
      min_maxes.first.map { |x| [x] }
    end
  end

  def parameters
    @parameters
  end

end