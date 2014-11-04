unless Rails.env.test?
  CappedCollectionMongoActiveRecord.create_capped_collection
end