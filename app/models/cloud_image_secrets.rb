class CloudImageSecrets < EncryptedMongoActiveRecord

  def self.collection_name
    'cloud_image_secrets'
  end

end