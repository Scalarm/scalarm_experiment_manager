module DBHelper

  DATABASE_NAME = 'scalarm_db_test'

  def setup
    unless MongoActiveRecord.connected?
      MongoActiveRecord.connect_to_db_with_name DATABASE_NAME
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