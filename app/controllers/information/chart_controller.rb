class Information::ChartController < Information::AbstractServiceController
  def self.service_name
    'Chart Service'
  end

  def self.model_class
    Information::ChartService
  end
end
