require_relative '../../abstract_cloud_client'

module PLCloud

  class CloudClient < AbstractCloudClient
    def self.short_name
      'plcloud'
    end
    def self.full_name
      'PLGrid Cloud'
    end
  end

end