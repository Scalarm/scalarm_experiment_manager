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
    @experiment.stubs(:get_statistics).returns([10, 2, 8])

    refute @experiment.has_simulations_to_run?
  end

  def test_has_more_simulations
    @experiment.stubs(:is_running).returns(true)
    @experiment.stubs(:experiment_size).returns(11)
    @experiment.stubs(:get_statistics).returns([11, 2, 8])

    assert @experiment.has_simulations_to_run?
  end

  def test_end_not_running
    @experiment.stubs(:is_running).returns(false).once
    @experiment.stubs(:experiment_size).never
    @experiment.stubs(:get_statistics).never

    assert (@experiment.end?)
  end

  def test_end_all_done
    @experiment.stubs(:is_running).returns(true).once
    @experiment.stubs(:experiment_size).returns(10).once
    @experiment.stubs(:get_statistics).returns([10, 10, 10]).once

    assert @experiment.end?
  end

  def test_end_not
    @experiment.stubs(:is_running).returns(true).once
    @experiment.stubs(:experiment_size).returns(10).once
    @experiment.stubs(:get_statistics).returns([10, 10, 5]).once

    refute (@experiment.end?)
  end

end