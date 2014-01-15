# deprecated
#CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'cloud_modules.yml'))

PROVIDERS_DIR = File.join(Rails.root, 'app/models/infrastructure_facades/clouds/providers')
PROVIDER_NAMES = ((Dir.new(PROVIDERS_DIR).entries.map {|f| f.match(/^(.*)\.rb$/)}).select { |m| m }).map {|m| m[1]}

def provider_path(name)
  "#{PROVIDERS_DIR}/#{name}.rb"
end

PROVIDER_NAMES.each do |name|
  require_relative provider_path(name)
end

def find_module_name(content)
  m = content.match(/module (.*)/)
  m and m[1]
end

class CloudFactory

  def self.infrastructures_hash
    Hash[PROVIDER_NAMES.map do |name|
          c_class = Object.const_get(find_module_name(File.read(provider_path(name))))::CloudClient
          [c_class.short_name.to_sym, {label: c_class.full_name, facade: CloudFacade.new(c_class)}]
        end]
  end

  # deprecated
  #def self.create_facade(cloud_name)
  #  CloudFacade.new(Object.const_get(CONFIG[cloud_name])::CloudClient)
  #end

end
