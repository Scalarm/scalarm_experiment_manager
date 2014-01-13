# Fields:
# cloud_name: string - cloud name, e.g. 'amazon'
# user_id: ScalarmUser id who has this secrets
#
# other fields are user defined and should be of String class to enable encryption!

class CloudSecrets < EncryptedMongoActiveRecord

  def self.collection_name
    'cloud_secrets'
  end

  def self.all_for_cloud(cloud_name)
    find_all_by('cloud_name', cloud_name)
  end

end