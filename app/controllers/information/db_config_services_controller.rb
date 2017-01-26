class Information::DbConfigServicesController < Information::AbstractServiceController
  def self.service_name
    'DbConfigService'
  end

  def self.model_class
    Information::DbConfigService
  end
end
