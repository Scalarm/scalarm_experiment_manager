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

  def test_plgoid_dn_to_browser_dn
    plg_dn = 'CN=plgjliput,CN=Jakub Liput,O=AGH,O=Uzytkownik,O=PL-Grid,C=PL'
    browser_dn = '/C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput'

    assert_equal browser_dn, PlGridOpenID.plgoid_dn_to_browser_dn(plg_dn)
  end

  def test_browser_dn_to_plgoid_dn
    plg_dn = 'CN=plgjliput,CN=Jakub Liput,O=AGH,O=Uzytkownik,O=PL-Grid,C=PL'
    browser_dn = '/C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput'

    assert_equal plg_dn, PlGridOpenID.browser_dn_to_plgoid_dn(browser_dn)
  end

end