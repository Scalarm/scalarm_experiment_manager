module DBHelper
  DATABASE_NAME = 'scalarm_db_test'

<<<<<<< HEAD
  require 'scalarm/database/core/mongo_active_record'

  def setup
    unless Scalarm::Database::MongoActiveRecord.connected?
      connection_init = Scalarm::Database::MongoActiveRecord.connection_init('localhost', DATABASE_NAME)
      raise StandardError.new('Connection to database failed') unless connection_init
      puts "Connecting to database #{DATABASE_NAME}"
=======
  def setup(database_name=DATABASE_NAME)
    unless MongoActiveRecord.connected?
      raise StandardError.new('Connection to database failed') unless MongoActiveRecord.connection_init('localhost', database_name)
      puts "Connecting to database #{database_name}"
>>>>>>> future
    end
  end

  # Drop all collections after each test case.
<<<<<<< HEAD
  def teardown
    db = Scalarm::Database::MongoActiveRecord.get_database(DATABASE_NAME)
=======
  def teardown(database_name=DATABASE_NAME)
    db = MongoActiveRecord.get_database(database_name)
>>>>>>> future
    db.collections.each do |collection|
      collection.remove unless collection.name.start_with? 'system.'
    end
  end
end