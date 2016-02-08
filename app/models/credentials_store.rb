require 'cluster_credentials'

# Single access point to credentials related to different infrastructures
# ClusterCredentials, GridCredentials, PrivateMachineCredentials, etc.
class CredentialsStore

  def self.get_credentials(user_id, infrastructure_type, infrastructure_identifier)
    if infrastructure_type == 'clusters'

      cluster_id = infrastructure_identifier.split("_").last
      ClusterCredentials.where(owner_id: user_id, cluster_id: cluster_id).first

    # elsif infrastructure_type == 'grids'

    else

      nil

    end
  end

end
