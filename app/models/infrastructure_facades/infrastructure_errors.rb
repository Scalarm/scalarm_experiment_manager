module InfrastructureErrors
  class InfrastructureError < StandardError; end

  class NoCredentialsError < InfrastructureError; end
  class InvalidCredentialsError < InfrastructureError; end
  class CloudError < InfrastructureError; end
  class NoSuchInfrastructureError < InfrastructureError; end
  class NoSuchSimulationManagerError < InfrastructureError; end
  class AccessDeniedError < InfrastructureError; end
  class ScheduleError < InfrastructureError; end
end
