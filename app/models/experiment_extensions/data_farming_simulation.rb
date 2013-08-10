module DataFarmingSimulation

  def simulation_collection_name
    "experiment_instances_#{self.experiment_id}"
  end

  def simulation_collection
    MongoActiveRecord.get_collection(simulation_collection_name)
  end

  def create_simulation_table
    collection = simulation_collection

    raise('No Experiment Instance DB available') if collection.nil?

    collection.create_index([['id', Mongo::ASCENDING]])
    collection.create_index([['is_done', Mongo::ASCENDING]])
    collection.create_index([['to_sent', Mongo::ASCENDING]])

    # sharding collection
    cmd = BSON::OrderedHash.new
    cmd['enableSharding'] = collection.db.name
    begin
      MongoActiveRecord.execute_raw_command_on('admin', cmd)
    rescue Exception => e
      Rails.logger.error(e)
    end

    cmd = BSON::OrderedHash.new
    cmd['shardcollection'] = "#{collection.db.name}.#{simulation_collection_name}"
    cmd['key'] = {'id' => 1}
    begin
      MongoActiveRecord.execute_raw_command_on('admin', cmd)
    rescue Exception => e
      Rails.logger.error(e)
    end
  end

  def find_simulations_by(query, options = { sort: [ ['id', :asc] ] })
    simulations = []

    simulation_collection.find(query, options).each{|doc| simulations << ExperimentInstance.new(doc)}

    simulations
  end

  def find_simulation_docs_by(query, options = { sort: [ ['id', :asc] ] })
    simulations = []

    simulation_collection.find(query, options).each{|doc| Rails.logger.debug("Doc: #{doc}"); simulations << doc}

    simulations
  end

end