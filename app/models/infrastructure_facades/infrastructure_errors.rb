module InfrastructureErrors
  class NoCredentialsError < StandardError; end
  class InvalidCredentialsError < StandardError; end
  class CloudError < StandardError; end
  class NoSuchInfrastructureError < StandardError; end
  class NoSuchSimulationManagerError < StandardError; end
  class AccessDeniedError < StandardError; end
  class ScheduleError < StandardError; end
end
