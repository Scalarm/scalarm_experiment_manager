require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class PrivateMachineFacadeTest < MiniTest::Test

  def stub_record(user_id, experiment_id)
    r = Object.new
    r.stubs(:user_id).returns(user_id)
    r.stubs(:experiment_id).returns(experiment_id)
    r
  end

  def test_get_infrastructure_sm_records
    # given
    user1_id = 1
    user2_id = 2

    experiment1_id = 'a'
    experiment2_id = 'b'

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user1_id})
    .returns([
                 stub_record(user1_id, experiment1_id),
                 stub_record(user1_id, experiment1_id),
                 stub_record(user1_id, experiment2_id)
             ])

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user2_id})
    .returns([
                 stub_record(user2_id, experiment1_id),
                 stub_record(user2_id, experiment2_id)
             ])

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user1_id, experiment_id: nil})
    .returns(PrivateMachineRecord.find_all_by_query({user_id: user1_id}))

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user1_id, experiment_id: experiment1_id})
    .returns([
                 stub_record(user1_id, experiment1_id),
                 stub_record(user1_id, experiment1_id)
             ])


    facade = PrivateMachineFacade.new

    # when
    user1_records = facade.get_sm_records(user1_id)
    user1_exp1_records = facade.get_sm_records(user1_id, experiment1_id)

    # then
    assert_equal 3, user1_records.count
    assert user1_records.all? {|r| r.user_id == user1_id}

    assert_equal 2, user1_exp1_records.count
    assert user1_exp1_records.all? {|r| r.user_id == user1_id and r.experiment_id == experiment1_id}
  end

end