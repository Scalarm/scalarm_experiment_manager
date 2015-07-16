module DBHelper
  DATABASE_NAME = 'scalarm_db_test'

  require 'scalarm/database/core/mongo_active_record'

  def setup(database_name=DATABASE_NAME)
    Scalarm::Database::MongoActiveRecord.set_encryption_key('db_key')

    unless Scalarm::Database::MongoActiveRecord.connected?
      connection_init = Scalarm::Database::MongoActiveRecord.connection_init('localhost', database_name)
      raise StandardError.new('Connection to database failed') unless connection_init
      puts "Connecting to database #{database_name}"
    end
  end

  # Drop all collections after each test case.
  def teardown(database_name=DATABASE_NAME)
    db = Scalarm::Database::MongoActiveRecord.get_database(database_name)
    db.collections.each do |collection|
      collection.remove unless collection.name.start_with? 'system.' or collection.capped?
    end
  end
end