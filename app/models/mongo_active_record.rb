require 'bson'
require 'mongo'
require 'json'

class MongoActiveRecord
  include Mongo

  def self.execute_raw_command_on(db, cmd)
    @@db.connection.db(db).command(cmd)
  end

  def self.get_collection(collection_name)
    @@db.collection(collection_name)
  end

  # object instance constructor based on map of attributes (json document is good example)
  def initialize(attributes)
    @attributes = {}

    attributes.each do |parameter_name, parameter_value|
      #parameter_value = BSON::ObjectId(parameter_value) if parameter_name.end_with?("_id")
      @attributes[parameter_name] = parameter_value
    end
  end

  # handling getters and setters for object instance
  def method_missing(method_name, *args, &block)
    #Rails.logger.debug("MongoRecord: #{method_name} - #{args.join(',')}")
    method_name = method_name.to_s; setter = false
    if method_name.ends_with? '='
      method_name.chop!
      setter = true
    end

    method_name = '_id' if method_name == 'id'

    if setter
      @attributes[method_name] = args.first
    elsif @attributes.include?(method_name)
      @attributes[method_name]
    else
      nil
      #super(method_name, *args, &block)
    end
  end

  # save/update json document in db based on attributes
  # if this is new object instance - _id attribute will be added to attributes
  def save
    collection = Object.const_get(self.class.name).send(:collection)

    if @attributes.include? '_id'
      collection.update({'_id' => @attributes['_id']}, @attributes, {:upsert => true})
    else
      id = collection.save(@attributes)
      @attributes['_id'] = id
    end
  end

  def destroy
    return if not @attributes.include? '_id'

    collection = Object.const_get(self.class.name).send(:collection)
    collection.remove({ '_id' => @attributes['_id'] })
  end

  def to_s
    if self.nil?
      'Nil'
    else
      <<-eos
      MongoActiveRecord - #{self.class.name} - Attributes - #{@attributes}\n
      eos
    end
  end

  #### Class Methods ####

  def self.collection_name
    raise 'This is an abstract method, which must be implemented by all subclasses'
  end

  # returns a reference to mongo collection based on collection_name abstract method
  def self.collection
    class_collection = @@db.collection(self.collection_name)
    raise "Error while connecting to #{self.collection_name}" if class_collection.nil?

    class_collection
  end

  # find by dynamic methods
  def self.method_missing(method_name, *args, &block)
    if method_name.to_s.start_with?('find_by')
      parameter_name = method_name.to_s.split('_')[2..-1].join('_')

      return self.find_by(parameter_name, args)

    elsif method_name.to_s.start_with?('find_all_by')
      parameter_name = method_name.to_s.split('_')[3..-1].join('_')

      return self.find_all_by(parameter_name, args)
    end

    super(method_name, *args, &block)
  end

  def self.all
    collection = Object.const_get(name).send(:collection)
    instances = []

    collection.find({}).each do |attributes|
      instances << Object.const_get(name).send(:new, attributes)
    end

    instances
  end

  def self.destroy(selector)
    collection = Object.const_get(name).send(:collection)

    collection.remove(selector)
  end

  def self.find_by_query(query)
    collection = Object.const_get(name).send(:collection)

    attributes = collection.find_one(query)

    if attributes.nil?
      nil
    else
      Object.const_get(name).new(attributes)
    end
  end

  def self.find_all_by_query(query)
    collection = Object.const_get(name).send(:collection)

    collection.find(query).map do |attributes|
      Object.const_get(name).new(attributes)
    end
  end

  def self.find_by(parameter, value)
    value = value.first if value.is_a? Enumerable

    if parameter == 'id'
      value = BSON::ObjectId(value.to_s)
      parameter = '_id'
    end

    collection = Object.const_get(name).send(:collection)

    attributes = collection.find_one({ parameter => value })

    if attributes.nil?
      nil
    else
      Object.const_get(name).new(attributes)
    end
  end

  def self.find_all_by(parameter, value)
    value = value.first if value.is_a? Enumerable

    if parameter == 'id'
      value = BSON::ObjectId(value.to_s)
      parameter = '_id'
    end

    collection = Object.const_get(name).send(:collection)

    collection.find({parameter => value}).map do |attributes|
      Object.const_get(name).new(attributes)
    end

  end

  # INITIALIZATION STUFF

  def self.connection_init(storage_manager_url, db_name)
    begin
      @@client = MongoClient.new(storage_manager_url.split(':')[0], storage_manager_url.split(':')[1])
      @@db = @@client[db_name]
      @@grid = Mongo::Grid.new(@@db)
    rescue Exception => e
      puts "Could not initialize connection with MongoDB --- #{e}"
    end

    Rails.logger.debug("MongoActiveRecord initialized with URL '#{storage_manager_url}' and DB '#{db_name}'")
  end

  # class initizalization
  config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
  information_service = InformationService.new(config['information_service_url'], config['information_service_user'], config['information_service_pass'])
  storage_manager_list = information_service.get_list_of('db_routers')

  MongoActiveRecord.connection_init(storage_manager_list.sample, config['db_name'])

end