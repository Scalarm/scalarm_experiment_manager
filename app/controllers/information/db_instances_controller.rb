class Information::DbInstancesController < Information::AbstractServiceController
  def self.service_name
    'DbInstance'
  end

  def self.model_class
    Information::DbInstance
  end
end
