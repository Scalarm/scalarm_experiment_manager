require_relative '../../abstract_cloud_client'

module AmazonCloud

  class CloudClient < AbstractCloudClient
    def self.short_name
      'amazon'
    end
    def self.full_name
      'Amazon Elastic Compute Cloud'
    end
  end

end