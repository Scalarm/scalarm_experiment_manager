require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'


class AuthenticationTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super
  end

  def teardown
    super
    Scalarm::ServiceCore::Utils.unstub(:header_newlines_deserialize)
  end

  def test_authentication_proxy_success
    require 'scalarm/service_core/grid_proxy'
    require 'scalarm/service_core/scalarm_authentication'

    header_proxy = 'serialized proxy frome header'
    proxy = mock 'deserialized proxy'
    proxy_obj = mock 'proxy obj' do
      stubs(:class).returns(Scalarm::ServiceCore::GridProxy::Proxy)
      stubs(:username).returns('plguser')
      stubs(:dn).returns('dn')
      expects(:verify_for_plgrid!).at_least_once
    end
    user_id = BSON::ObjectId.new
    em_scalarm_user = mock 'scalarm_user' do
      stubs(:id).returns(user_id)
    end
    scalarm_user = mock 'scalarm user' do
      stubs(:id).returns(user_id)
      stubs(:convert_to).with(ScalarmUser).returns(em_scalarm_user)
    end

    Scalarm::ServiceCore::Utils.stubs(:header_newlines_deserialize).with(header_proxy).returns(proxy)
    Scalarm::ServiceCore::GridProxy::Proxy.stubs(:new).with(proxy).returns(proxy_obj)
    Scalarm::ServiceCore::ScalarmUser.expects(:authenticate_with_proxy).
        at_least_once.with(proxy_obj, false).returns(scalarm_user)
    UserSession.stubs(:create_and_update_session) do |_user_id, session_id|
      _user_id == user_id
    end

    get '/', {}, { Scalarm::ServiceCore::ScalarmAuthentication::RAILS_PROXY_HEADER => header_proxy,
                   'HTTP_ACCEPT' => 'application/json' }

    assert_response :success, response.code
    assert_equal 'ok', JSON.parse(response.body)['status']

    # session creation on proxy authentication was disabled
    # assert_equal user_id.to_s, session[:user]
  end

  def test_authentication_proxy_fail
    require 'scalarm/service_core/grid_proxy'
    require 'scalarm/service_core/scalarm_authentication'

    header_proxy = 'serialized proxy frome header'
    proxy = mock 'deserialized proxy'
    proxy_obj = mock 'proxy obj' do
      stubs(:username).returns('plguser')
      stubs(:dn).returns('dn')
      expects(:verify_for_plgrid!).at_least_once.
          raises(Scalarm::ServiceCore::GridProxy::ProxyValidationError.new('test fail'))
    end
    user_id = BSON::ObjectId.new
    scalarm_user = mock 'scalarm user' do
      stubs(:id).returns(user_id)
    end

    Scalarm::ServiceCore::Utils.stubs(:header_newlines_deserialize).with(header_proxy).returns(proxy)
    Scalarm::ServiceCore::GridProxy::Proxy.stubs(:new).with(proxy).returns(proxy_obj)
    Scalarm::ServiceCore::ScalarmUser.stubs(:authenticate_with_proxy).with(proxy_obj, false).returns(scalarm_user)
    Scalarm::ServiceCore::ScalarmUser.stubs(:authenticate_with_proxy).with(proxy_obj, true).returns(nil)
    UserSession.stubs(:create_and_update_session) do |_user_id, session_id|
      _user_id == user_id
    end

    get '/', {}, { Scalarm::ServiceCore::ScalarmAuthentication::RAILS_PROXY_HEADER => header_proxy,
                   'HTTP_ACCEPT' => 'application/json' }

    assert_response 401, response.code
    assert_equal 'error', JSON.parse(response.body)['status']
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

  def test_basic_auth_success
    login = 'user'
    password = 'pass'

    u = ScalarmUser.new(login: login)
    u.password = password
    u.save

    get '/', {}, {
               'HTTP_ACCEPT' => 'application/json',
               'HTTP_AUTHORIZATION' =>
                   ActionController::HttpAuthentication::Basic.encode_credentials(login, password)
           }

    assert_response :success, response.body
  end

end