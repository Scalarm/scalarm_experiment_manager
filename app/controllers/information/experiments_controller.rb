class Information::ExperimentsController < Information::AbstractServiceController
  def self.service_name
    'Experiment Manager'
  end

  def self.model_class
    Information::ExperimentManager
  end

  # Override parent: add self address if no addresses are registered
  def generate_address_list
    adresses = super
    adresses.blank? ? [ request.host_with_port ] : adresses
  end
end
