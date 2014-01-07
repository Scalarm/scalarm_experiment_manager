require_relative '../../cloud_client'

class PLCloudClient < CloudClient
  def self.short_name
    'plcloud'
  end
  def self.full_name
    'PLGrid Cloud'
  end
end