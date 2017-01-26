class Information::SupervisorController < Information::AbstractServiceController
  def self.service_name
    'Experiment Supervisor'
  end

  def self.model_class
    Information::ExperimentSupervisor
  end
end
