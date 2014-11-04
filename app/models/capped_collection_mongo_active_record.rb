class CappedCollectionMongoActiveRecord < MongoActiveRecord
  def self.collection_name
    'capped_collection'
  end

  def self.create_capped_collection
    unless @@db.collection_names.include? self.collection_name
      #TODO: choose size and max
      @@db.create_collection(self.collection_name, :capped => true, :size => 1048576, :max => 10000)
      dummy = self.new('dummy'=>'object')
      dummy.save
    end
  end
end