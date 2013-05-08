require "bson"

class ExperimentInstanceDb < ActiveRecord::Base
  has_many :experiment_partitions

  @@shared_instance = nil
  @@shared_connection = nil
  @@database_name = 'scalarm_db'

  def self.get_random_id
    ExperimentInstanceDb.all[rand(ExperimentInstanceDb.count)].id
  end
  
  def self.default_instance
    if @@shared_instance.nil?
      @@shared_instance = ExperimentInstanceDb.new(:ip => '127.0.0.1', :port => 27017)
    end
    
    @@shared_instance
  end
  
  def default_connection
    if @@shared_connection.nil?
      begin
        @@shared_connection = Mongo::Connection.new(self.ip, self.port).db(@@database_name)
      rescue Exception => e
        Rails.logger.debug("Error while connecting to mongodb - #{e}")
        nil
      end
    end
    
    @@shared_connection
  end
  
  def self.create_table_for(experiment_id)
    mongo_start = Time.now

    collection = self.default_instance.connect_to_collection(experiment_id)

    raise('No Experiment Instance DB available') if collection.nil?

    collection.create_index([["id", Mongo::ASCENDING]])
    collection.create_index([["is_done", Mongo::ASCENDING]])
    collection.create_index([["to_sent", Mongo::ASCENDING]])
    collection.create_index([["priority", Mongo::ASCENDING]])
    
    # sharding collection
    cmd = BSON::OrderedHash.new
    cmd["enableSharding"] = @@database_name
    begin
      Mongo::Connection.new(ExperimentInstanceDb.default_instance.ip, ExperimentInstanceDb.default_instance.port).db("admin").command(cmd)
    rescue Exception => e
      Rails.logger.error(e)
    end
    
    cmd = BSON::OrderedHash.new
    cmd["shardcollection"] = "#{@@database_name}.#{ExperimentInstanceDb.default_instance.collection_name(experiment_id)}"
    cmd["key"] = { "id" => 1 }
    begin
      Mongo::Connection.new(ExperimentInstanceDb.default_instance.ip, ExperimentInstanceDb.default_instance.port).db("admin").command(cmd)
    rescue Exception => e
      Rails.logger.error(e)
    end

    mongo_end = Time.now
    Rails.logger.debug("MONGO_PROF:QUERY-create_experiment_instance_table|id=#{experiment_id}:Time-#{mongo_end-mongo_start}")
  end

  def connect_to_collection(experiment_id)
    self.default_connection.nil? ? nil : self.default_connection.collection(collection_name(experiment_id))
  end

  def collection_name(experiment_id)
    "experiment_instances_#{experiment_id}"
  end

  def self.collection_name(experiment_id)
    "experiment_instances_#{experiment_id}"
  end

  def find_one(experiment_id, query = {})
    collection = connect_to_collection(experiment_id)
    raise "Error while connecting to #{self.ip}" if collection.nil?

    collection.find_one(query)
  end

  def count_with_query(experiment_id, query = {})
    collection = connect_to_collection(experiment_id)
    raise "Error while connecting to #{self.ip}" if collection.nil?

    collection.count(:query => query)
  end

  def find_one_with_order(experiment_id, query, order = [])
    collection = connect_to_collection(experiment_id)
    raise "Error while connecting to #{self.ip}" if collection.nil?

    collection.find_one(query, {:sort => order})
  end

  def save_instance(instance_doc)
    collection = connect_to_collection(instance_doc["experiment_id"])
    raise "Error while connecting to #{self.ip}" if collection.nil?

    collection.update({"id" => instance_doc["id"]}, instance_doc, {:upsert => true})
  end

  def drop_instances_for(experiment_id)
    collection = connect_to_collection(experiment_id)
    raise "Error while connecting to #{self.ip}" if collection.nil?

    collection.drop
  end

  def find(experiment_id, query = {}, options = {})
    instance_docs = []

    collection = connect_to_collection(experiment_id)
    raise "Error while connecting to #{self.ip}" if collection.nil?

    collection.find(query, options).each{|doc| instance_docs << doc }
    instance_docs
  end

  def bulk_insert(experiment_id, docs)
    collection = connect_to_collection(experiment_id)
    raise "Instances already inserted"  if not collection.find_one({ "id" => docs.first["id"] }).nil?

    collection.insert(docs)
  end

  def update(experiment_id, selector, update_hash)
    collection = connect_to_collection(experiment_id)
    collection.update(selector, update_hash)
  end

  def log_mongo(experiment_id, action, params, time)
    Rails.logger.debug("MONGO_PROF|" +
      "Table-#{collection_name(experiment_id)}|" +
      "Action-#{action.to_s[0..100]}|" +
      "Params-#{params.to_s[0..100]}|" +
      "Time-#{"%.2f" % ((time)*1000)}ms")
  end
  
  def store_experiment_info(experiment, labels, value_list, multiply_list)
    collection = self.default_connection.collection("experiments_info")

    doc = {
          "experiment_id" => experiment.id,
          "is_running" => experiment.is_running,
          "experiment_size" => experiment.experiment_size,
          "labels" => labels,
          "value_list" => value_list,
          "multiply_list" => multiply_list,
          "time_constraint_in_sec" => experiment.time_constraint_in_sec,
          "time_constraint_in_iter" => experiment.time_constraint_in_iter}

    collection.insert(doc)
  end
  
  def get_experiment_info(experiment_id)
    cache_key = "experiment_info_#{experiment_id}"

    experiment_hash = Rails.cache.read(cache_key)
    if experiment_hash.nil?
      collection = self.default_connection.collection("experiments_info")
      experiment_hash = collection.find_one({"experiment_id" => experiment_id})
      Rails.cache.write(cache_key, experiment_hash, :expires_in => 60)
    end

    experiment_hash
  end

end
