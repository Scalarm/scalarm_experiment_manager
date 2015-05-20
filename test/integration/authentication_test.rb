require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'


class ExperimentIntegrationTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super
  end

  def teardown
    super
  end

  def test_login_access_proxy
    require 'grid-proxy'

    header_proxy = 'serialized proxy frome header'
    proxy = mock 'deserialized proxy'
    proxy_obj = mock 'proxy obj' do
      stubs(:username).returns('plguser')
      stubs(:dn).returns('dn')
      expects(:verify_for_plgrid!).at_least_once
    end
    user_id = BSON::ObjectId.new
    scalarm_user = mock 'scalarm user' do
      stubs(:id).returns(user_id)
    end

    Utils.stubs(:header_newlines_deserialize).with(header_proxy).returns(proxy)
    GP::Proxy.stubs(:new).with(proxy).returns(proxy_obj)
    ScalarmUser.expects(:authenticate_with_proxy).at_least_once.with(proxy_obj, false).returns(scalarm_user)
    UserSession.stubs(:create_and_update_session) do |_user_id, session_id|
      _user_id == user_id
    end

    get '/', {}, { ScalarmAuthentication::RAILS_PROXY_HEADER => header_proxy, 'HTTP_ACCEPT' => 'application/json' }

    assert_response :success, response.code
    assert_equal 'ok', JSON.parse(response.body)['status']

    # session creation on proxy authentication was disabled
    # assert_equal user_id.to_s, session[:user]
  end

  def test_token
    u = ScalarmUser.new(login: 'user')
    u.save
    s = UserSession.create_and_update_session(u.id, '1')
    token = s.generate_token
    s.save

    get '/', {token: token}, {'HTTP_ACCEPT' => 'application/json'}

    assert_response :success, response.body
  end

end