class Information::ExperimentsController < Information::AbstractServiceController
  def self.service_name
    'Experiment Manager'
  end

  def self.model_class
    Information::ExperimentManager
  end
end
