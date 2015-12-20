require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentTest < MiniTest::Test

  def setup
    @experiment = Experiment.new({})
  end

  def test_add_to_shared
    experiment = Experiment.new({})
    user_id = mock 'user_id'
    experiment.expects(:shared_with=).with([user_id])

    experiment.add_to_shared(user_id)
  end

  def test_share_with_anonymous
    user_id = mock 'user_id'
    anonymous_user = mock 'anonymous_user' do
      stubs(:id).returns(user_id)
    end
    ScalarmUser.stubs(:get_anonymous_user).returns(anonymous_user)

    experiment = Experiment.new({})
    experiment.expects(:add_to_shared).with(user_id)

    experiment.share_with_anonymous
  end

  def test_double_share_with_anonymous
    user_id = mock 'user_id'
    anonymous_user = mock 'anonymous_user' do
      stubs(:id).returns(user_id)
    end
    ScalarmUser.stubs(:get_anonymous_user).returns(anonymous_user)

    experiment = Experiment.new({})
    experiment.expects(:add_to_shared).with(user_id).once

    experiment.stubs(:shared_with).returns(nil)
    experiment.share_with_anonymous
    experiment.stubs(:shared_with).returns([user_id])
    experiment.share_with_anonymous
  end

  def test_all_already_sent
    @experiment.stubs(:is_running).returns(true)
    @experiment.stubs(:experiment_size).returns(10)
    @experiment.stubs(:count_all_generated_simulations).returns(10)
    @experiment.stubs(:count_sent_simulations).returns(2)
    @experiment.stubs(:count_done_simulations).returns(8)

    refute @experiment.has_simulations_to_run?
  end

  def test_has_more_simulations
    @experiment.stubs(:is_running).returns(true)
    @experiment.stubs(:experiment_size).returns(11)
    @experiment.stubs(:count_all_generated_simulations).returns(11)
    @experiment.stubs(:count_sent_simulations).returns(2)
    @experiment.stubs(:count_done_simulations).returns(8)

    assert @experiment.has_simulations_to_run?
  end

  def test_end_not_running
    @experiment.stubs(:is_running).returns(false).once
    @experiment.stubs(:experiment_size).never
    @experiment.stubs(:count_all_generated_simulations).never
    @experiment.stubs(:count_sent_simulations).never
    @experiment.stubs(:count_done_simulations).never

    assert (@experiment.end?)
  end

  def test_end_all_done
    @experiment.stubs(:is_running).returns(true).once
    @experiment.stubs(:experiment_size).returns(10).once
    @experiment.stubs(:count_done_simulations).returns(10).once

    assert @experiment.end?
  end

  def test_end_not
    @experiment.stubs(:is_running).returns(true).once
    @experiment.stubs(:experiment_size).returns(10).once
    @experiment.stubs(:count_done_simulations).returns(5).once

    refute (@experiment.end?)
  end

  def test_replication_level
    @experiment.size = nil
    @experiment.replication_level = 5
    @experiment.parameter_constraints = nil
    @experiment.stubs(:value_list).returns([[1, 2, 3], [1, 2]])

    assert_equal 30, @experiment.experiment_size
  end

end