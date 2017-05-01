class MongoActiveRecordIndexBuilder

  def self.build_index(record_class)
    record_collection = record_class.collection

    record_class._indexed_attributes.each do |attr|
      Rails.logger.info "Checking if an index for '#{attr}' exists ..."
      index_exist = false

      record_collection.indexes.each do |index_info|
        if attr.is_a?(Hash)
          if (index_info["key"].keys - attr.keys.map(&:to_s)).empty?
            index_exist = true
          end
        else
          if index_info["key"].include?(attr.to_s)
            index_exist = true
          end
        end
      end

      unless index_exist
        Rails.logger.info "Index for '#{attr}' does not exist so we create it"
        if attr.is_a?(Hash)
          record_collection.indexes.create_one({ attr => 1 }, unique: true)
        else
          record_collection.indexes.create_one({ attr.to_sym => 1 }, unique: true)
        end
      else
        Rails.logger.info "Index for '#{attr}' exists"
      end
    end
  end

end