require_relative 'providers/amazon/amazon_client'
require_relative 'providers/pl_cloud/pl_cloud_client'

class CloudFactory

  # TODO: move to config file?
  CLOUD_CLIENTS = {
      'amazon' => AmazonClient,
      'plcloud' => PLCloudClient
  }

  def self.create_facade(cloud_name)
    CloudFacade.new(CLOUD_CLIENTS[cloud_name])
  end
end
