require 'csv'
require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class PrivateMachineTest < Test::Unit::TestCase

  def setup
  end

  def test_get_running_simulation_managers
    # given
    user1_records_count = 3
    user2_records_count = 5

    user1 = ScalarmUser.new({})
    user1.stubs(:id).returns(1)
    user2 = ScalarmUser.new({})
    user2.stubs(:id).returns(2)

    PrivateMachineRecord.stubs(:find_all_by_user_id).with(user1.id)
      .returns((1..user1_records_count).map do
      r = PrivateMachineRecord.new({})
      r.stubs(:user_id).returns(user1.id)
      r
    end)

    PrivateMachineRecord.stubs(:find_all_by_user_id).with(user2.id)
      .returns((1..user2_records_count).map do
      r = PrivateMachineRecord.new({})
      r.stubs(:user_id).returns(user2.id)
      r
    end)

    facade = PrivateMachineFacade.new

    # when
    user1_records = facade.get_running_simulation_managers(user1)
    user2_records = facade.get_running_simulation_managers(user2)

    # then
    assert_equal user1_records.count, user1_records_count
    assert user1_records.all? {|r| r.user_id == user1.id}

    assert_equal user2_records.count, user2_records_count
    assert user2_records.all? {|r| r.user_id == user2.id}
  end

end