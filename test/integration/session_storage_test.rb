require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'
require 'controller_integration_test_helper'

require 'db_helper'

class TestsController < ApplicationController
  def set_variables
    params[:variables] ||= {}

    params[:variables].to_hash.each do |k, v|
      session[k.to_sym] = v
    end

    render nothing: true
  end

  def get_variables
    params[:variables] ||= []

    render json: session.to_hash.slice(*params[:variables])
  end

  def delete_variables
    params[:variables] ||= []

    params[:variables].each do |key|
      session.delete(key)
    end

    render nothing: true
  end

  def reset
    reset_session
    render nothing: true
  end

  def ping
    render nothing: true
  end
end

# Tests is session objects (session, flash) are working properly
# as session-persistent hashes
class SessionStorageTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super

    authenticate_session!

    Rails.application.routes.draw do
      get 'set_variables' => 'tests#set_variables'
      get 'delete_variables' => 'tests#delete_variables'
      get 'get_variables' => 'tests#get_variables'
      get 'reset' => 'tests#reset'
      get 'ping' => 'tests#ping'

      # add original some original routes
      root 'user_controller#index'
      post 'login' => 'user_controller#login'
    end
  end

  def teardown
    super
    Rails.application.reload_routes!
  end

  test 'session variables can be set and read between requests' do
    get '/set_variables', {variables: {a: 'one', b: 'two'}}

    get '/get_variables', {variables: %w(a b)}
    body = JSON.parse(response.body)

    assert_equal 'one', body['a']
    assert_equal 'two', body['b']
  end

  test 'session variables can be modified between requests' do
    get '/set_variables', {variables: {a: 'foo'}}
    get '/set_variables', {variables: {a: 'foo2'}}

    get '/get_variables', {variables: ['a']}
    body = JSON.parse(response.body)

    assert_equal 'foo2', body['a']
  end

  test 'session variables can be deleted' do
    get 'set_variables', {one: 1}
    get 'delete_variables', {variables: ['one']}

    get 'get_variables', {variables: ['one']}
    body = JSON.parse(response.body)
    assert_empty body
  end

  test 'after resetting session, authentication should fail' do
    # make request with session - it should succeed
    # reset session on that request
    get 'reset'
    assert_response :success

    # next request with session should fail
    get 'ping', format: :json
    assert_response :unauthorized
  end

  test 'after resetting session, its document should be removed from db' do
    # clear UserSession collection
    UserSession.each &:destroy

    # authenticate
    authenticate_session!

    # make request with session - user_session should be the session doc
    # document in db with user_session.id should be available in UserSession collection
    get 'ping'

    # the collection should contain equal one document
    assert_equal 1, UserSession.count
    assert_equal UserSession.first.session_id.to_s, session[:user].to_s

    # reset session
    get 'reset'

    # UserSession collection should be empty now
    assert_empty UserSession.all
  end

end