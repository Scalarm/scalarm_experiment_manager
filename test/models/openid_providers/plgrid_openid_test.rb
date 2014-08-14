require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'openid_providers/plgrid_openid'

class PlGridOpenIDTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end

  def test_get_or_create_user_both
    dn = mock 'dn'
    plglogin = mock 'plglogin'
    user = mock 'user'

    OpenIDUtils.stubs(:get_user_with).with(dn: dn, login: plglogin).returns(user)
    OpenIDUtils.stubs(:get_user_with).with(dn: dn).returns(user)
    OpenIDUtils.stubs(:get_user_with).with(login: plglogin).returns(user)

    assert_equal user, PlGridOpenID::get_or_create_user(dn, plglogin)
  end

  def test_get_or_create_user_only_dn
    dn = mock 'dn'
    plglogin = mock 'plglogin'
    user = mock 'user'

    OpenIDUtils.stubs(:get_user_with).with(dn: dn, login: plglogin).returns(nil)
    OpenIDUtils.stubs(:get_user_with).with(dn: dn).returns(user)
    OpenIDUtils.stubs(:get_user_with).with(login: plglogin).returns(nil)

    assert_equal user, PlGridOpenID::get_or_create_user(dn, plglogin)
  end

  def test_get_or_create_user_only_login
    dn = mock 'dn'
    plglogin = mock 'plglogin'
    user = mock 'user'

    OpenIDUtils.stubs(:get_user_with).with(dn: dn, login: plglogin).returns(nil)
    OpenIDUtils.stubs(:get_user_with).with(dn: dn).returns(nil)
    OpenIDUtils.stubs(:get_user_with).with(login: plglogin).returns(user)

    assert_equal user, PlGridOpenID::get_or_create_user(dn, plglogin)
  end

  def test_get_or_create_user_none
    dn = mock 'dn'
    plglogin = mock 'plglogin'
    user = mock 'user'

    OpenIDUtils.stubs(:get_user_with).with(dn: dn, login: plglogin).returns(nil)
    OpenIDUtils.stubs(:get_user_with).with(dn: dn).returns(nil)
    OpenIDUtils.stubs(:get_user_with).with(login: plglogin).returns(nil)

    OpenIDUtils.expects(:create_user_with).with(plglogin, login: plglogin, dn: dn).returns(user)

    refute_nil PlGridOpenID::get_or_create_user(dn, plglogin)
  end

end