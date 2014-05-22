class DependencyInjectionFactory

  attr_accessor :provider_names
  attr_accessor :client_classes

  def initialize(classes_dir, dependency_class_name, base_facade_class)
    @provider_names = []
    @classes_dir = classes_dir
    @dependency_class_name = dependency_class_name
    @client_classes = {}
    @module_names = {}
    @base_facade_class = base_facade_class

    load_dependencies
  end

  def load_dependencies
    provider_path = lambda do |name|
      "#{@classes_dir}/#{name}.rb"
    end

    @provider_names = ((Dir.new(@classes_dir).entries.map {|f| f.match(/^(.*)\.rb$/)}).select { |m| m }).map {|m| m[1]}

    @provider_names.each do |name|
      require_dependency provider_path.(name)
      @module_names[name] = DependencyInjectionFactory.find_module_name(File.read(provider_path.(name)))
    end

    @provider_names.each do |name|
      @client_classes[name] = client_class(name) # force initialization of all client_classes
      Rails.logger.info("#{self.class.to_s}: Loaded infrastructure class: #{name}")
    end
  end

  def long_name(short_name)
    client_class(short_name).long_name
  end

  def client_class(short_name)
    @client_classes[short_name] ||= Object.const_get("#{@module_names[short_name]}::#{@dependency_class_name}")
  end

  def get_facade(short_name)
    @base_facade_class.new(client_class(short_name))
  end

  private

  def self.find_module_name(content)
    m = content.match(/module (.*)/)
    m and m[1]
  end

end