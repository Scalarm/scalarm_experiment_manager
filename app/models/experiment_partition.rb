require "experiment_instance_db"

class ExperimentPartition < ActiveRecord::Base
  belongs_to :experiment
  belongs_to :experiment_instance_db
  
  def self.find(id)
    cache_key = "experiment_partition_#{id}"
    cached = Rails.cache.read(cache_key)
    
    if cached.nil?
      # Rails.logger.debug("ExperimentPartition #{id} NOT IN CACHE")
      cached = ExperimentPartition.find_by_id(id)
      Rails.cache.write(cache_key, cached, :expires_in => 600.seconds)
    else
      # Rails.logger.debug("ExperimentPartition #{id} IN CACHE")
    end
    
    cached
  end
  # def experiment_instance_db
    # ExperimentInstanceDb.find(self.experiment_instance_db_id)
    # # super.experiment_instance_db
#     
    # # cache_key = "shard_db_#{self.experiment_instance_db_id}"
    # # cached = Rails.cache.read(cache_key)
# #     
    # # if cached.nil?
      # # # Rails.logger.debug("ExperimentInstanceDb #{id} NOT IN CACHE")
      # # cached = ExperimentInstanceDb.find_by_id(self.experiment_instance_db_id)
      # # Rails.cache.write(cache_key, cached, :expires_in => 600.seconds)
    # # else
      # # # Rails.logger.debug("ExperimentInstanceDb #{id} IN CACHE")
    # # end
# #     
    # # cached
  # end

  def create_table
    mongo_start = Time.now

    collection = self.experiment_instance_db.connect_to_collection(experiment.id)
    if collection.nil?
      ExperimentInstanceDb.all.shuffle.each do |instance_db|
        self.experiment_instance_db = instance_db
        collection = self.experiment_instance_db.connect_to_collection(experiment.id)
        if not collection.nil?
          self.save
          break
        end
      end
    end
    
    if collection.nil?
      raise("No Experiment Instance DB available")
    end

    collection.create_index([["id", Mongo::ASCENDING]])
    collection.create_index([["is_done", Mongo::ASCENDING]])
    collection.create_index([["to_sent", Mongo::ASCENDING]])
    collection.create_index([["priority", Mongo::ASCENDING]])

    mongo_end = Time.now
    Rails.logger.debug("MONGO_PROF:QUERY-create_experiment_instance_table|id=#{experiment.id}:Time-#{mongo_end-mongo_start}")
  end

  def bulk_insert(experiment_id, docs)
    self.experiment_instance_db.bulk_insert(experiment_id, docs)
  end

  def self.find_for_instance_id(experiment_id, instance_id)
    self.all_for_experiment(experiment_id).find{|partition|
      partition.start_id <= instance_id.to_i and partition.end_id >= instance_id.to_i
    }
  end
  
  def self.find_for_instances(experiment_id, first_instance_id, last_instance_id)
    first_partition = self.find_for_instance_id(experiment_id, first_instance_id)
    last_partition = self.find_for_instance_id(experiment_id, last_instance_id)
    
    # if first_partition.id != last_partition.id
  end

# TODO FIXME this should be cached somehow
  def self.all_for_experiment(experiment_id)
    # Rails.logger.debug { "BEFORE" }
    # cache_key = "experiment_partitions_for_#{experiment_id}"
    # cached = Rails.cache.read(cache_key)
#     
    # if cached.nil?
      # Rails.logger.debug("ExperimentPartitions for #{experiment_id} NOT IN CACHE")
      ExperimentPartition.where(:experiment_id => experiment_id).includes(:experiment_instance_db).to_a
      # Rails.cache.write(cache_key, cached.map{|p| p.id}.join(","), :expires_in => 600.seconds)
    # else
      # # Rails.logger.debug("ExperimentPartitions for #{experiment_id} IN CACHE")
      # cached = cached.split(",").map{|partition_id| ExperimentPartition.find(partition_id)}
    # end
#     
    # cached
  end

  def self.drop_partitions_for(experiment_id)
    ExperimentPartition.all_for_experiment(experiment_id).each do |partition|
      partition.destroy
    end
  end

end
