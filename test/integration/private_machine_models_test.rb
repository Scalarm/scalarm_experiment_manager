require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class PrivateMachineModelsTest < Test::Unit::TestCase

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
  end

  def test_collect_simulation_managers
    # given
    facade = PrivateMachineFacade.new
    PrivateMachineRecord.new(user_id: 1, experiment_id: 1, credentials_id: 1).save
    PrivateMachineRecord.new(user_id: 1, experiment_id: 2, credentials_id: 2).save
    PrivateMachineRecord.new(user_id: 2, experiment_id: 1, credentials_id: 3).save
    PrivateMachineRecord.new(user_id: 2, experiment_id: 2, credentials_id: 4).save

    # when
    u1 = facade.get_all_simulation_managers user_id: 1
    u2e2 = facade.get_container_all_simulation_managers user_id: 2, experiment_id: 2

    # then
    assert_equal 2, u1.count

    assert_equal 1, u2e2.count
    assert_equal 4, u2e2[0].record.credentials_id

  end

end