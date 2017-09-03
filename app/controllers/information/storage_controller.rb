class Information::StorageController < Information::AbstractServiceController

  def self.service_name
    'Storage Manager'
  end

  def self.model_class
    Information::StorageManager
  end

  # Override parent: add self fake storage address if no addresses are registered
  def generate_address_list
    adresses = super
    adresses.blank? ? [ "#{request.host_with_port}/storage" ] : adresses
  end

end
