class ExperimentProgressNotification < CappedMongoActiveRecord

  def self.collection_name
    "experiment_progress_notifications"
  end

  def self.capped_size
    1048576
  end

  def self.capped_max
    50000
  end

end
