# Fields:
# user_id: ScalarmUser id who has this secrets
# access_key - actually stored as hashed_access_key
# secret_key - actually stored as hashed_secret_key

class AmazonSecrets < MongoActiveRecord

  def self.collection_name
    'amazon_secrets'
  end

  def access_key
    Base64.decode64(self.hashed_access_key).decrypt
  end

  def access_key=(new_access_key)
    self.hashed_access_key = Base64.encode64(new_access_key.encrypt)
  end

  def secret_key
    Base64.decode64(self.hashed_secret_key).decrypt
  end

  def secret_key=(new_secret_key)
    self.hashed_secret_key = Base64.encode64(new_secret_key.encrypt)
  end

end