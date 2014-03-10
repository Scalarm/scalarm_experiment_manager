require 'test/unit'
require 'mocha'

class SmNodesTest < Test::Unit::TestCase

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
  end

  def teardown
  end

  def test_get_nodes

    get InfrastructuresController

    fail('Not implemented')
  end
end