module DBHelper
  DATABASE_NAME = 'scalarm_db_test'

  def setup(database_name=DATABASE_NAME)
    unless MongoActiveRecord.connected?
      raise StandardError.new('Connection to database failed') unless MongoActiveRecord.connection_init('localhost', database_name)
      puts "Connecting to database #{database_name}"
    end
  end

  # Drop all collections after each test case.
  def teardown(database_name=DATABASE_NAME)
    db = MongoActiveRecord.get_database(database_name)
    db.collections.each do |collection|
      collection.remove unless collection.name.start_with? 'system.'
    end
  end
end