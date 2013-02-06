require "bson"

class MongoActiveRecord
  @@db = ExperimentInstanceDb.default_instance.default_connection

  # object instance constructor based on map of attributes (json document is good example)
  def initialize(attributes)
    @attributes = attributes
  end

  # handling getters and setters for object instance
  def method_missing(method_name, *args, &block)
    method_name = method_name.to_s; setter = false
    if method_name.ends_with? "="
      method_name.chop!
      setter = true
    end

    if setter
      @attributes[method_name] = args.first
    elsif @attributes.include?(method_name)
      @attributes[method_name]
    else
      super(method_name, *args, &block)
    end
  end

  # save/update json document in db based on attributes
  # if this is new object instance - _id attribute will be added to attributes
  def save
    Rails.logger.debug("Save method in #{self.class.name}")
    collection = Object.const_get(self.class.name).send(:collection)

    if @attributes.include? "_id"
      collection.update({"_id" => @attributes["_id"]}, @attributes, {:upsert => true})
    else
      id = collection.save(@attributes)
      @attributes["_id"] = id
    end
  end

  def destroy
    return if not @attributes.include? "_id"

    collection = Object.const_get(self.class.name).send(:collection)
    collection.remove({ "_id" => @attributes["_id"] })
  end

  #### Class Methods ####

  def self.collection_name
    raise "This is an abstract method, which must be implemented by all subclasses"
  end

  # returns a reference to mongo collection based on collection_name abstract method
  def self.collection
    Rails.logger.debug("Getting collection")
    Rails.logger.debug("Getting collection by name - #{self.collection_name}")
    class_collection = @@db.collection(self.collection_name)
    raise "Error while connecting to #{self.collection_name}" if class_collection.nil?

    class_collection
  end

  # find by dynamic methods
  def self.method_missing(method_name, *args, &block)
    if method_name.to_s.start_with?("find_by")
      parameter_name = method_name.to_s.split("_")[2..-1].join("_")

      return self.find_by(parameter_name, args)
    end

    super(method_name, *args, &block)
  end

  def self.all
    Rails.logger.debug("All method for #{name} class")
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

  private

  def self.find_by(parameter, value)
    if parameter == "id"
      value = BSON::ObjectId(value.first)
      parameter = "_id"
    end

    collection = Object.const_get(name).send(:collection)

    attributes = collection.find_one({ parameter => value })

    if not attributes.nil?
      Object.const_get(name).new(attributes)
    else
      nil
    end
  end

end