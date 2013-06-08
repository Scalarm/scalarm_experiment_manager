require "bson"
require "set"

require "experiment_partition"

class ExperimentInstance

  def initialize(attributes)
    @mongo_doc = attributes
  end

  def mongo_doc
    @mongo_doc
  end

  # handling getters and setters
  def method_missing(m, *args, &block)
    method_name = m.to_s; setter = false
    if method_name.ends_with? "="
      method_name.chop!
      setter = true
    end

    if setter
      @mongo_doc[method_name] = args.first
    elsif @mongo_doc.include?(method_name)
      @mongo_doc[method_name]
    elsif method_name == "experiment"
      Experiment.find(@mongo_doc["experiment_id"])
    end
  end

  def save
    begin
      ExperimentInstanceDb.default_instance.save_instance(@mongo_doc)
    rescue Exception => e
      Rails.logger.debug("Error in 'save_instance' --- #{e}")
    end
  end

  def output_values
    self.result.split(',').map { |item| item.split("=")[1] }
  end

  def self.columns
    @columns ||= [];
  end

  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end

  def self.get_statistics(experiment_id)
    done = ExperimentInstance.count_with_query(experiment_id, {"is_done" => true})
    sent = ExperimentInstance.count_with_query(experiment_id, {"to_sent" => false})

    return done, sent - done
  end

  def self.drop_instances_for(experiment_id)
    begin
      ExperimentInstanceDb.default_instance.drop_instances_for(experiment_id)

    rescue Exception => e
      Rails.logger.debug("Error in 'drop_instances_for' --- #{e}")
    end
  end

  def self.get_avg_execution_time_of_ei(experiment_id)
    summary_runtime, counter = 0, 0
    
    ExperimentInstance.raw_find_by_query(experiment_id, { "is_done" => true }, { :fields => ["done_at", "sent_at"], :limit => 10000, :sort => [["done_at", :desc]] }).each do |doc|
      begin
        summary_runtime += (doc["done_at"] - doc["sent_at"]) 
        counter += 1
      rescue Exception => e
        Rails.logger.error(e)
      end
        
    end
    
    counter > 0 ? (summary_runtime / counter) : 0
  end

  def self.bulk_insert(experiment_id, combinations, labels)
    docs_to_insert = combinations.map{|doc| Hash[*labels.zip(doc).flatten] }
    ExperimentInstanceDb.default_instance.bulk_insert(experiment_id, docs_to_insert)
    # slice_count, num_of_rows = partition_instances_by_size(docs_to_insert)
# 
    # counter = 0
    # while counter * num_of_rows < docs_to_insert.size
# 
      # rows_to_insert = docs_to_insert[(counter*num_of_rows)...((counter+1)*num_of_rows)]
      # ExperimentInstanceDb.default_instance.bulk_insert(experiment_id, rows_to_insert)
# 
      # counter += 1
    # end
  end

  def self.partition_instances_by_size(docs_to_insert)
    row_size = docs_to_insert[0].to_s.size
    mongo_limit_size = 16000000
    num_of_rows = (mongo_limit_size / (row_size*1.7)).to_i

    if num_of_rows > docs_to_insert.size
      return docs_to_insert.size, num_of_rows
    else
      return docs_to_insert.size / num_of_rows, num_of_rows
    end
  end

  def self.count_with_query(experiment_id, query = {})    
    ExperimentInstanceDb.default_instance.count_with_query(experiment_id, query)
  end

  def self.find_by_id(experiment_id, instance_id)
    instance_hash = ExperimentInstanceDb.default_instance.find_one(experiment_id, {'id' => instance_id.to_i})
    instance_hash.nil? ? nil : ExperimentInstance.new(instance_hash)
  end

  def self.get_first_done(experiment_id)
    begin
      instance_doc = ExperimentInstanceDb.default_instance.find_one(experiment_id, {"is_done" => true})
      return ExperimentInstance.new(instance_doc) if not instance_doc.nil?
    rescue Exception => e
      Rails.logger.debug("Error in 'count_with_query' --- #{e}")
    end

    return nil
  end

  def self.get_arguments(experiment_id)
    result = ExperimentInstance.raw_find_by_query(experiment_id, {}, { limit: 1, fields: %w(arguments)})
    if result.size >= 1
      result[0]['arguments']
    else
      nil
    end
  end

  def self.find_expired_instances(experiment_id, time_constraint_in_secs)
    expired_instances = []
    send_condition = {'is_done' => false, 'to_sent' => false}

    now = Time.now
    
    begin
      ExperimentInstanceDb.default_instance.find(experiment_id, send_condition).each do |instance_doc|
        if now - instance_doc["sent_at"] >= time_constraint_in_secs * 2
          expired_instances << ExperimentInstance.new(instance_doc)
        end
      end
    rescue Exception => e
      Rails.logger.debug("Error during connection to instance db at #{ExperimentInstanceDb.default_instance.ip} ")
    end

    expired_instances
  end

  def self.find_by_query(experiment_id, query)
    ExperimentInstanceDb.default_instance.find(experiment_id, query)
  end
  
  require "set"

  def self.raw_find_by_query(experiment_id, query, options = {})
    begin
      ExperimentInstanceDb.default_instance.find(experiment_id, query, options).to_a
    rescue Exception => e
      Rails.logger.debug("Error in 'count_with_query' --- #{e}")
      []
    end  
  end
  
  def self.cache_get(experiment_id, instance_id)
    cache_key = "simulation_#{experiment_id}_#{instance_id}"
    cached = Rails.cache.read(cache_key)
    
    if cached.nil?
      # Rails.logger.debug("ExperimentInstance #{instance_id} for experiment #{experiment_id} NOT IN CACHE")
      cached = ExperimentInstance.find_by_id(experiment_id, instance_id)
      Rails.cache.write(cache_key, cached)
    else
      # Rails.logger.debug("ExperimentInstance #{instance_id} for experiment #{experiment_id} IN CACHE")
    end
    
    cached
  end
  
  def put_in_cache
    Rails.cache.write("simulation_#{self.experiment.id}_#{self.id}", self)
  end
  
  def remove_from_cache
    Rails.cache.delete("simulation_#{self.experiment.id}_#{self.id}")
  end

end
