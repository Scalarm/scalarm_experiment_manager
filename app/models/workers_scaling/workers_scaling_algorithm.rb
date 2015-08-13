##
# Class describing interface of Workers scaling algorithm. Creating new algorithm
# requires providing class with proper methods implemented, which also should
# inherit WorkersScalingAlgorithm class.
class WorkersScalingAlgorithm

  NOT_IMPLEMENTED = 'This is an abstract method, which must be implemented by all subclasses'

  ##
  # Method called when algorithm is starting, before first execution of
  # #experiment_status_check. Should contain actions performed in the
  # beginning of algorithm e.g. sending first workers on infrastructure.
  def initial_deployment
    raise NOT_IMPLEMENTED
  end

  ##
  # Main algorithm loop, executed on specified event (e.g. finished simulation) or
  # when given time since last execution passed. Should contain main algorithm logic.
  def experiment_status_check
    raise NOT_IMPLEMENTED
  end

end