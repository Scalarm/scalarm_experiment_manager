require 'scalarm/database/core/mongo_active_record'
require 'infrastructure_facades/infrastructure_facade_factory'
require 'credentials_store'

##
# Represents a remote cluster with a queuing system
# ==== Fields:
# infrastructure_type:: enum - indicating infrastructure the job will run on,
#                       e.g. plgrid, clouds, clusters or private_machine
# infrastructure_identifier:: string - identifier of an infrastructure acceptable by
#                       InfrastructureFacadeFactory.get_facade_for method
# user:: user_id - who created the job
# created_at:: timestamp - when the record was created the job
# job_identifier:: string - infrastructure-specific string uniquely identifying the job

class JobRecord < Scalarm::Database::MongoActiveRecord
  include SimulationManagerRecord
  use_collection 'jobs'

  attr_join :user, ScalarmUser

  def resource_id
    self.job_identifier
  end

  def infrastructure_name
    InfrastructureFacadeFactory.get_facade_for(self.infrastructure_identifier).short_name
  end

  def credentials
    @credentials ||= CredentialsStore.get_credentials(user.id, infrastructure_type, infrastructure_identifier)
  end

end
