require 'scalarm/database/model'

# For model documentation see documentation of Scalarm::Database::Model::CloudImageSecrets
class CloudImageSecrets < Scalarm::Database::Model::CloudImageSecrets
  attr_join :user, ScalarmUser

  # Image secrets are considered always valid, because to verify, real VM must be created
  def valid?
    true
  end
end