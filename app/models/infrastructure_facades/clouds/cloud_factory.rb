# TODO?
require_relative 'providers/amazon/amazon'

class CloudFactory

  CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'cloud_modules.yml'))

  def self.create_facade(cloud_name)
    CloudFacade.new(Object.const_get(CONFIG[cloud_name])::CloudClient)
  end
end
