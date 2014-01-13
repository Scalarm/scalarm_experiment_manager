CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'cloud_modules.yml'))

CONFIG.keys.each do |k|
  require_relative "providers/#{k}.rb"
end

class CloudFactory

  def self.create_facade(cloud_name)
    CloudFacade.new(Object.const_get(CONFIG[cloud_name])::CloudClient)
  end

end
