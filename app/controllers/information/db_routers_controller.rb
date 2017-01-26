class Information::DbRoutersController < Information::AbstractServiceController
  def self.service_name
    'DbRouter'
  end

  def self.model_class
    Information::DbRouter
  end
end
