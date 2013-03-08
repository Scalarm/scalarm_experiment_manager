require 'active_record'
require_relative 'experiment_instance_db'
require_relative 'mongo_active_record'

# Properties
# manager_id - integer
# hostname - string
# created_at - date

class ExperimentManager < MongoActiveRecord

  def self.collection_name
    'experiment_managers'
  end

end