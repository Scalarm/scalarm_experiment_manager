require "mongo"
require "bson"

#require_relative "experiment_instance_db"

# Properties
# manager_id - integer
# hostname - string
# created_at - date

class ExperimentManager
  @@db_connection = nil
  @@table_name = "experiment_managers"

  attr_accessor :attributes_hash

  def initialize(attributes)
    @attributes_hash = attributes
  end

  def self.collection
    @@db_connection = Mongo::Connection.new("localhost").db("eusas_db") if @@db_connection.nil?
    @@db_connection[@@table_name]
  end

  # handling getters and setters
  def method_missing(m, *args, &block)
    method_name = m.to_s; setter = false
    if method_name.end_with? "="
      method_name.chop!
      setter = true
    end

    if setter
      @attributes_hash[method_name] = args.first
    elsif @attributes_hash.include?(method_name)
      @attributes_hash[method_name]
    end
  end

  def save(initial = false)
    begin
      ExperimentManager.collection.save(@attributes_hash)

      if initial
        @attributes_hash["manager_id"] = @@db_connection[@@table_name].count()
        @attributes_hash["created_at"] = Time.now

        save
      end

    rescue Exception => e
      puts("Error when saving ExperimentManager -- #{e}")
    end
  end

  def destroy
    query = {"manager_id" => @attributes_hash["manager_id"]}
    raise "Error while connecting" if ExperimentManager.collection.nil?

    mongo_start = Time.now

    ExperimentManager.collection.remove(query, {})

    mongo_end = Time.now
    ExperimentManager.log_mongo("destroy", query, mongo_end-mongo_start)
  end

  def self.find(query = {}, options = {})
    manager_docs = []

    raise "Error while connecting" if ExperimentManager.collection.nil?

    mongo_start = Time.now

    ExperimentManager.collection.find(query, options).each { |doc| manager_docs << doc }

    mongo_end = Time.now
    ExperimentManager.log_mongo("find", query, mongo_end-mongo_start)

    manager_docs.map{|manager_doc| ExperimentManager.new(manager_doc)}
  end

  def self.find_one(query = {}, options = {})
    list_of_managers = self.find(query, options)

    if list_of_managers.empty?
      nil
    else
      list_of_managers.first
    end
  end

  def self.count(query = {})
    counter = 0

    raise "Error while connecting" if ExperimentManager.collection.nil?

    mongo_start = Time.now

    counter = ExperimentManager.collection.count(query)

    mongo_end = Time.now
    ExperimentManager.log_mongo("count", query, mongo_end-mongo_start)

    counter
  end

  def self.log_mongo(action, params, time)
    puts("MONGO_PROF|" +
                           "Table-experiment_managers|" +
                           "Action-#{action.to_s[0..100]}|" +
                           "Params-#{params.to_s[0..100]}|" +
                           "Time-#{"%.2f" % ((time)*1000)}ms")
  end

  #def self.columns
  #  @columns ||= [];
  #end
  #
  #def self.column(name, sql_type = nil, default = nil, null = true)
  #  columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  #end
end