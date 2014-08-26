require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentTest < MiniTest::Test

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

end