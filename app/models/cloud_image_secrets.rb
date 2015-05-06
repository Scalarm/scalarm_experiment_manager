# Mandatory fields:
# user_id => ScalarmUser id
# image_id: fixnum => id of image in Cloud
# experiment_id => DataFarmingExperiment id
# cloud_name: string => one of Cloud short names, e.g. 'pl_cloud', 'amazon'
#
# other fields are cloud-specific, e.g. image_login, secret_password, secret_token

require 'scalarm/database/model'

class CloudImageSecrets < Scalarm::Database::Model::CloudImageSecrets
  attr_join :user, ScalarmUser

  # Image secrets are considered always valid, because to verify, real VM must be created
  def valid?
    true
  end
end