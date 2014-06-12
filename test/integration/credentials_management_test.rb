require 'mocha'
require 'minitest/autorun'
require 'test_helper'

class CredentialsManagementTest < ActionController::TestCase
  tests InfrastructuresController

  def setup
    # MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    # MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}

    @tmp_user_id = '1'
    @tmp_user = ScalarmUser.new({login: 'test', _id: @tmp_user_id})
    ScalarmUser.stubs(:find_by_id).with(@tmp_user_id).returns(@tmp_user)
  end

  def teardown
  end

  def test_overwrite_credentials
    credentials = mock 'credentials' do
      stubs(:valid?).returns(true)
      expects(:invalid=).never
    end

    facade = stub_everything 'facade' do
      stubs(:add_credentials).returns(credentials)
    end

    GridCredentials.stubs(:find_by_user_id).with(@tmp_user_id).returns(credentials)
    InfrastructureFacadeFactory.stubs(:get_facade_for).with('testing').returns(facade)

    post :add_infrastructure_credentials,
         {infrastructure_type: 'testing'}, {user: @tmp_user_id}

    response_json = JSON.parse(response.body)

    assert_equal 'ok', response_json['status'], response.body
  end

  def test_invalid_credentials
    credentials = mock 'credentials' do
      stubs(:valid?).returns(false)
      expects(:invalid=).with(true).once
      expects(:save).at_least_once
    end

    facade = stub_everything 'facade' do
      stubs(:add_credentials).returns(credentials)
    end

    GridCredentials.stubs(:find_by_user_id).with(@tmp_user_id).returns(credentials)
    InfrastructureFacadeFactory.stubs(:get_facade_for).with('testing').returns(facade)

    post :add_infrastructure_credentials,
         {infrastructure_type: 'testing'}, {user: @tmp_user_id}

    response_json = JSON.parse(response.body)

    assert_equal 'error', response_json['status'], response.body
  end

  def test_add_credentials_exception
    credentials = mock 'credentials' do
      expects(:valid?).never
    end

    facade = stub_everything 'facade' do
      stubs(:add_credentials).raises(StandardError.new('some error'))
    end

    GridCredentials.stubs(:find_by_user_id).with(@tmp_user_id).returns(credentials)
    InfrastructureFacadeFactory.stubs(:get_facade_for).with('testing').returns(facade)

    post :add_infrastructure_credentials,
         {infrastructure_type: 'testing'}, {user: @tmp_user_id}

    response_json = JSON.parse(response.body)

    assert_equal 'error', response_json['status'], response.body
  end
end