require 'scalarm/database/core/mongo_active_record'

##
# Represents a remote cluster with a queuing system
# ==== Fields:
# name:: descriptive name of a cluster, e.g. Prometheus @ ACC Cyfronet AGH
# scheduler:: name (enum) of a queuing system, which manages the cluster
# host:: string (url) of an access node from which jobs can be submitted
# created_by:: id of a user who defined the cluster
# shared_with:: list of users ids who will see this cluster definition
# public:: boolean if this definition should be shared with everyone
class ClusterRecord < Scalarm::Database::MongoActiveRecord
  use_collection 'clusters'

  def visible_to?(user_id)
    self.public == true or
      self.created_by == user_id or
        (self.shared_with.kind_of?(Array) and self.shared_with.include?(user_id))
  end

end
