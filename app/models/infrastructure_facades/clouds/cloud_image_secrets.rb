class CloudImageSecrets < EncryptedMongoActiveRecord
  def self.encryption_excluded
    %w(cloud_name image_id)
  end
end