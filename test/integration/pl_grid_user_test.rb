require 'test_helper'
require 'db_helper'

require 'openid_providers/openid_utils'

class PlGridUserTest < ActiveSupport::TestCase
  include DBHelper

  def setup
    super

    @user = ScalarmUser.new(login: 'plguser', dn: '/C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=PlGrid User/CN=plguser')
    @user.save

    @gc = GridCredentials.new(user_id: @user.id, secret_proxy: 'proxy', host: 'somewhere.com')
  end

  def teardown
    super
  end

  test 'valid_plgrid_credentials should return nil if no valid GridCredentials exists' do
    assert_nil @user.valid_plgrid_credentials('example.com')
  end

  test 'valid_plgrid_credentials should return nil if existing GridCredentials is not valid for a given host' do
    @gc.stubs(:valid?).returns(false)
    @gc.save

    assert_nil @user.valid_plgrid_credentials('example.com')
  end

  test 'valid_plgrid_credentials should return GridCredentials if existing GridCredentials is valid for a given host' do
    @gc.stubs(:valid?).returns(true)
    @gc.save

    assert @gc, @user.valid_plgrid_credentials('example.com')
  end

end