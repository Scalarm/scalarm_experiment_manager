# TODO?
require_relative 'providers/amazon/cloud_client'
require_relative 'providers/pl_cloud/cloud_client'

class CloudFactory

  config = YAML.load_file(File.join(Rails.root, 'config', 'cloud_modules.yml'))

  def self.create_facade(cloud_name)
    CloudFacade.new(Object.const_get(config[cloud_name])::Client)
  end
end
