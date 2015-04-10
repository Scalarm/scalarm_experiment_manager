module DBHelper

  DATABASE_NAME = 'scalarm_db_test'

  # DB Router should listen on localhost on default port
  def setup
    unless MongoActiveRecord.connected?
      raise StandardError.new('Connection to database failed') unless MongoActiveRecord.connection_init('localhost', DATABASE_NAME)
      puts "Connecting to database #{DATABASE_NAME}"
    end
  end

  # Drop all collections after each test case.
  def teardown
    db = MongoActiveRecord.get_database(DATABASE_NAME)
    db.collections.each do |collection|
      collection.remove unless collection.name.start_with? 'system.'
    end
  end
end