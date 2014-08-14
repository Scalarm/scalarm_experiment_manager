require 'mocha'
require 'minitest/autorun'
require 'test_helper'

class CredentialsManagementTest < ActionController::TestCase
  tests InfrastructuresController

  def setup
    @tmp_user_id = '1'
    @tmp_user = ScalarmUser.new({login: 'test', _id: @tmp_user_id})
    ScalarmUser.stubs(:find_by_id).with(@tmp_user_id).returns(@tmp_user)
  end

  def test_overwrite_credentials
    credentials = stub_everything 'credentials' do
      stubs(:valid?).returns(true)
    end

    InfrastructuresController.any_instance.expects(:mark_credentials_invalid).never
    InfrastructuresController.any_instance.expects(:mark_credentials_valid).once

    facade = stub_everything 'facade' do
      stubs(:add_credentials).returns(credentials)
    end

    GridCredentials.stubs(:find_by_user_id).with(@tmp_user_id).returns(credentials)
    InfrastructureFacadeFactory.stubs(:get_facade_for).with('testing').returns(facade)

    post :add_infrastructure_credentials,
         {infrastructure_name: 'testing'}, {user: @tmp_user_id}

    response_json = JSON.parse(response.body)

    assert_equal 'ok', response_json['status'], response.body
  end

  def test_invalid_credentials
    infrastructure_name = 'infrastructure_name'
    credentials = stub_everything 'credentials' do
      stubs(:valid?).returns(false)
    end

    InfrastructuresController.any_instance.expects(:mark_credentials_invalid)
      .with(credentials, infrastructure_name).once
    InfrastructuresController.any_instance.expects(:mark_credentials_valid).never

    facade = stub_everything 'facade' do
      stubs(:add_credentials).returns(credentials)
    end

    GridCredentials.stubs(:find_by_user_id).with(@tmp_user_id).returns(credentials)
    InfrastructureFacadeFactory.stubs(:get_facade_for).with(infrastructure_name).returns(facade)

    post :add_infrastructure_credentials,
         {infrastructure_name: infrastructure_name}, {user: @tmp_user_id}

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