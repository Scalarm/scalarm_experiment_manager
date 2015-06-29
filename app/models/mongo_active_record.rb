require 'bson'
require 'mongo'
require 'json'

class MongoActiveRecord
  include Mongo
  include MongoActiveRecordUtils

  attr_reader :attributes

  @conditions = {}
  @options = {}
  @@client = nil

  def self.ids_auto_convert
    true
  end

  def self.conditions
    @conditions
  end

  def self.conditions=(conds)
    @conditions = conds
  end

  def self.options
    @options
  end

  def self.options=(opts)
    @options = opts
  end

  def self.available?
    begin
      self.get_collection('test').find.first
      return true
    rescue
      return false
    end
  end

  def self.execute_raw_command_on(db, cmd)
    @@db.connection.db(db).command(cmd)
  end

  def self.get_collection(collection_name)
    @@db.collection(collection_name)
  end

  def self.shard_collection(collection_name)
    if @@client.mongos?
      cmd = BSON::OrderedHash.new
      cmd['enableSharding'] = @@db.name
      begin
        MongoActiveRecord.execute_raw_command_on('admin', cmd)
      rescue Exception => e
        Rails.logger.error(e)
      end

      cmd = BSON::OrderedHash.new
      cmd['shardcollection'] = "#{@@db.name}.#{collection_name}"
      cmd['key'] = {'index' => 1}
      begin
        MongoActiveRecord.execute_raw_command_on('admin', cmd)
      rescue Exception => e
        Rails.logger.error(e)
      end
    end
  end

  # object instance constructor based on map of attributes (json document is good example)
  def initialize(attributes)
    @attributes = {}
    # here we store all hash-like parameters to use them like hash but store them as strings
    @__hash_attributes = attributes['__hash_attributes'] || []

    attributes.each do |parameter_name, parameter_value|
      #parameter_value = BSON::ObjectId(parameter_value) if parameter_name.end_with?("_id")
      if @__hash_attributes.include? parameter_name.to_s
        @attributes[parameter_name.to_s] = JSON.parse parameter_value
      else
        @attributes[parameter_name.to_s] = parameter_value
      end
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
      set_attribute(method_name, args.first)
    elsif attributes.include?(method_name)
      get_attribute(method_name)
    else
      nil
      #super(method_name, *args, &block)
    end
  end

  def set_attribute(attribute, value)
    if value.is_a? Hash
      @__hash_attributes << attribute
    end

    @attributes[attribute] = value
  end

  def get_attribute(attribute)
    attributes[attribute]
  end

  def _delete_attribute(attribute)
    @__hash_attributes.delete attribute

    @attributes.delete(attribute)
  end

  # save/update json document in db based on attributes
  # if this is new object instance - _id attribute will be added to attributes
  def save
    @__hash_attributes.each do |hash_attr|
      @attributes[hash_attr] = @attributes[hash_attr].to_json
    end
    @attributes['__hash_attributes'] = @__hash_attributes

    if @attributes.include? '_id'
      self.class.collection.update({'_id' => @attributes['_id']}, @attributes, {upsert: true})
    else
      id = self.class.collection.save(@attributes)
      @attributes['_id'] = id
    end
  end

  def save_if_exists
    self.save if self.class.find_by_id(self.id)
  end

  def destroy
    return if not @attributes.include? '_id'

    self.class.collection.remove({ '_id' => @attributes['_id'] })
    @attributes.delete('_id')
  end

  def reload
    @attributes = self.class.find_by_query(id: self.id).attributes
    self
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

  def to_h
    Hash[attributes.keys.map do |key|
      value = self.send(key)
      [key, (value.kind_of?(BSON::ObjectId) ? value.to_s : value)]
    end]
  end

  def to_json
    to_h.to_json
  end

  #### Class Methods ####

  def self.connected?
    !@@client.nil?
  end

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

    elsif (not instance_methods.include?(method_name.to_sym)) and (Array.instance_methods.include?(method_name.to_sym))

      return to_a.send(method_name.to_sym, *args, &block)
    end

    super(method_name, *args, &block)
  end

  def self.all
    where({}, {}).to_a
  end

  def self.destroy(selector)
    self.collection.remove(selector)
  end

  def self.find_by_query(query)
    self.where(query, {limit: 1}).first
  end

  def self.find_all_by_query(query, opts = {})
    self.where(query, opts).to_a
  end

  def self.find_by(parameter, value)
    value = value.first if value.is_a? Enumerable
    self.find_by_query(parameter => value)
  end

  def self.find_all_by(parameter, value)
    value = value.first if value.is_a? Enumerable
    self.find_all_by_query(parameter => value)
  end

  def self.get_database(db_name)
    if @@client.nil?
      nil
    else
      @@client[db_name]
    end
  end

  # chaining capabilities
  def self.where(cond, opts = {})
    mongo_class = self.deep_dup
    mongo_class.conditions = @conditions.deep_dup || {}
    mongo_class.options = @options.deep_dup || {}

    cond.each do |key, value|
      key = key.to_sym
      key = :_id if key == :id

      if key == :_id
        value = BSON::ObjectId(value.to_s)
      elsif key.to_s.ends_with?('_id') and self.ids_auto_convert
        # some ugly hack - if ID can be converted to BSON (or is BSON) use both String and BSON in query
        # otherwise, use only stringified value
        bson_value = begin
          Utils::to_bson_if_string(value)
        rescue BSON::InvalidObjectId
          nil
        end

        str_value = value.to_s
        if bson_value
          value = {'$in' => [str_value, bson_value]}
        else
          value = str_value
        end
      end

      mongo_class.conditions[key] = value
    end

    mongo_class.options.merge! opts

    mongo_class
  end

  def self.to_a
    results = self.collection.find(@conditions || {}, @options || {}).map do |attributes|
      self.new(attributes)
    end

    @conditions = {}; @options = {}

    results
  end

  def self.size
    count
  end

  def self.count
    results = self.collection.count query: @conditions || {}, limit: (@options && @options[:limit]) || nil

    @conditions = {}; @options = {}

    results
  end


  # INITIALIZATION STUFF

  def self.connection_init(storage_manager_url, db_name)
    begin
      Rails.logger.debug("MongoActiveRecord initialized with URL '#{storage_manager_url}' and DB '#{db_name}'")

      @@client = MongoClient.new(storage_manager_url.split(':')[0], storage_manager_url.split(':')[1], {
          connect_timeout: 5.0, pool_size: 4, pool_timeout: 10.0
      })
      @@db = @@client[db_name]
      @@grid = Mongo::Grid.new(@@db)

      return true
    rescue Exception => e
      Rails.logger.debug "Could not initialize connection with MongoDB --- #{e}"
      @@client = @@db = @@grid = nil
    end

    false
  end

  # UTILS

  def self.parse_json_if_string(attribute)
    define_method attribute do
      Utils::parse_json_if_string(get_attribute(attribute.to_s))
    end
  end

  def self.next_sequence
    self.get_next_sequence(self.collection_name)
  end

  def self.get_next_sequence(name)
    collection = MongoActiveRecord.get_collection('counters')
    collection.find_and_modify({
                                   query: { _id: name },
                                   update: { '$inc' => { seq: 1 } },
                                   new: true,
                                   upsert: true
                               })['seq']
  end

end