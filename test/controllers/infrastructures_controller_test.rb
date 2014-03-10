class SessionsControllerTest < ActionController::TestCase
  tests InfrastructuresController

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
  end

  def teardown
  end

  def test_get_nodes

    get '/infrastructures/sm_nodes?name=pl_cloud'

    fail('Not implemented')
  end

end
