
class Notification < MongoActiveRecord

  def self.collection_name
    'notifications'
  end

  def initialize(attributes)
    attributes['timestamp'] = (Time.now.to_f * 1000).to_i

    super(attributes)
  end

end