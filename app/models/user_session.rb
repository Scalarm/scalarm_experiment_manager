require 'securerandom'

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

  def self.create_and_update_session(user_id, uuid)
    session_id = BSON::ObjectId(user_id)
    if uuid.nil?
      uuid = session[:session_uuid] = SecureRandom.uuid
    end

    session = (UserSession.where(session_id: session_id, uuid: uuid).first or
      UserSession.new(session_id: session_id, uuid: uuid))
    session.last_update = Time.now
    session.save

    session
  end

  def generate_token
    token = SecureRandom.uuid
    self.tokens = [] unless self.tokens
    self.tokens << token
    self.save
    token
  end

end
