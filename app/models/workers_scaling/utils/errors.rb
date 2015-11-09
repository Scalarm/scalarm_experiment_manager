module WorkersScaling
  class WorkersScalingError < StandardError; end
  class AlgorithmNameUnknown < WorkersScalingError; end
  class AlgorithmParameterMissing < WorkersScalingError; end
end