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
      [c_class.short_name.to_sym, {label: c_class.long_name, facade: CloudFacade.new(c_class)}]
    end]
  end

  # Selects only Clouds, for which secrets are defined
  # @return [Hash<String, String>] full cloud name => short name
  def self.provider_names_select(user_id)
    clouds_with_creds = CLIENT_CLASSES.select do |name, _|
      not CloudSecrets.find_by_query('cloud_name'=>name, 'user_id'=>user_id).nil?
    end

    Hash[clouds_with_creds.map {|name, client| [client.long_name, name]}]
  end

  def self.provider_names
    PROVIDER_NAMES
  end

  def self.long_name(short_name)
    client_class(short_name).long_name
  end

  

end
