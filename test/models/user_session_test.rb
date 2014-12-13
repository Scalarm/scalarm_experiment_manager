require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class UserSessionTest < MiniTest::Test

  def setup
    @user_session = UserSession.new({})
  end

  def test_valid
    Rails.configuration.stubs(:session_threshold).returns(120)
    @user_session.stubs(:last_update).returns(Time.now - 1.minutes)

    assert @user_session.valid?
  end

  def test_valid_expired
    Rails.configuration.stubs(:session_threshold).returns(60)
    @user_session.stubs(:last_update).returns(Time.now - 2.minutes)

    refute @user_session.valid?
  end

end