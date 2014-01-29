# deprecated
#CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'cloud_modules.yml'))

class CloudFactory

  PROVIDERS_DIR = File.join(Rails.root, 'app/models/infrastructure_facades/clouds/providers')

  def self.provider_path(name)
    "#{PROVIDERS_DIR}/#{name}.rb"
  end

  def self.find_module_name(content)
    m = content.match(/module (.*)/)
    m and m[1]
  end

  # TODO: runtime?

  PROVIDER_NAMES = ((Dir.new(PROVIDERS_DIR).entries.map {|f| f.match(/^(.*)\.rb$/)}).select { |m| m }).map {|m| m[1]}
  MODULE_NAMES = {}

  PROVIDER_NAMES.each do |name|
    require_relative provider_path(name)
    MODULE_NAMES[name] = find_module_name(File.read(provider_path(name)))
  end

  CLIENT_CLASSES = {}

  def self.client_class(cloud_name)
    CLIENT_CLASSES[cloud_name] = Object.const_get(MODULE_NAMES[cloud_name])::CloudClient unless CLIENT_CLASSES[name]
    CLIENT_CLASSES[cloud_name]
  end

  PROVIDER_NAMES.each do |name|
    CLIENT_CLASSES[name] = client_class(name)
  end

  def self.infrastructures_hash
    Hash[PROVIDER_NAMES.map do |name|
      c_class = client_class(name)
      [c_class.short_name.to_sym, {label: c_class.full_name, facade: CloudFacade.new(c_class)}]
    end]
  end

  def self.provider_names_select
    Hash[CLIENT_CLASSES.map {|sn, cli| [cli.full_name, sn]}]
  end

  def self.provider_names
    PROVIDER_NAMES
  end

end
