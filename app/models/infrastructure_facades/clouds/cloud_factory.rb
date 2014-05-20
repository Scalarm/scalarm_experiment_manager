class CloudFactory

  @@providers_dir = File.join(Rails.root, 'app/models/infrastructure_facades/clouds/providers')

  def self.provider_path(name)
    "#{@@providers_dir}/#{name}.rb"
  end

  def self.find_module_name(content)
    m = content.match(/module (.*)/)
    m and m[1]
  end

  @@provider_names = ((Dir.new(@@providers_dir).entries.map {|f| f.match(/^(.*)\.rb$/)}).select { |m| m }).map {|m| m[1]}
  @@module_names = {}

  @@provider_names.each do |name|
    require_relative provider_path(name)
    @@module_names[name] = find_module_name(File.read(provider_path(name)))
  end

  @@client_classes = {}

  def self.client_class(cloud_name)
    @@client_classes[cloud_name] = Object.const_get(@@module_names[cloud_name])::CloudClient unless @@client_classes[name]
    @@client_classes[cloud_name]
  end

  @@provider_names.each do |name|
    @@client_classes[name] = client_class(name)
  end

  def self.infrastructures_hash
    Hash[@@provider_names.map do |name|
      c_class = client_class(name)
      [c_class.short_name.to_sym, {label: c_class.long_name, facade: CloudFacade.new(c_class)}]
    end]
  end

  # Selects only Clouds, for which secrets are defined
  # @return [Hash<String, String>] full cloud name => short name
  def self.provider_names_select(user_id)
    clouds_with_creds = @@client_classes.select do |name, _|
      not CloudSecrets.find_by_query('cloud_name'=>name, 'user_id'=>user_id).nil?
    end

    Hash[clouds_with_creds.map {|name, client| [client.long_name, name]}]
  end

  def self.provider_names
    @@provider_names
  end

  def self.long_name(short_name)
    client_class(short_name).long_name
  end

  

end
