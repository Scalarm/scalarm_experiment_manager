class Information::StorageController < Information::AbstractServiceController

  def self.service_name
    'Storage Manager'
  end

  def self.model_class
    Information::StorageManager
  end

end
