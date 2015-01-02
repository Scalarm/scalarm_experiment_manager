class CappedMongoActiveRecord < MongoActiveRecord

  # returns a reference to mongo collection based on collection_name abstract method
  def self.collection
    class_collection = @@db.collection_names.include?(self.collection_name) ?
        @@db.collection(self.collection_name) : create_capped_collection

    raise "Error while connecting to #{self.collection_name}" if class_collection.nil?

    class_collection
  end

  def self.create_capped_collection
    cc = @@db.create_collection(self.collection_name, :capped => true, :size => capped_size, :max => capped_max)
    self.new('dummy'=>'object').save
    cc
  end

  def self.capped_size
    1048576
  end

  def self.capped_max
    10000
  end

end