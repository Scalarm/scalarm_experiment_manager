# Mandatory fields:
# user_id => ScalarmUser id
# image_id: fixnum => id of image in Cloud
# experiment_id => DataFarmingExperiment id
# cloud_name: string => one of Cloud short names, e.g. 'pl_cloud', 'amazon'
#
# other fields are cloud-specific, e.g. image_login, secret_password, secret_token

class CloudImageSecrets < EncryptedMongoActiveRecord

  def self.collection_name
    'cloud_image_secrets'
  end

end