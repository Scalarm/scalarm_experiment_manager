
class MongoLock < MongoActiveRecord

  def self.collection_name
    'mongo_locks'
  end

  def self.acquire(collection_name)
  	collection = self.get_collection(self.collection_name)

  	lock_dock = collection.find_and_modify({
  		query: { collection: collection_name },
  		update: { '$set' => { collection: collection_name } },
  		upsert: true
	})

	if lock_dock.nil? # lock acquired
		true
	else
		false
	end

  end

  def self.release(collection_name)
  	collection = self.get_collection(self.collection_name)
  	collection.remove({ collection: collection_name })
  end

end