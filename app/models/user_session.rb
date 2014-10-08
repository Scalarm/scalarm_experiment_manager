
class UserSession < MongoActiveRecord

  def self.collection_name
    'user_sessions'
  end

  def valid?
    if Time.now.to_i - self.last_update.to_i > Rails.configuration.session_threshold
      false
    else
      true
    end
  end

  def self.ids_auto_convert
    false
  end


end
