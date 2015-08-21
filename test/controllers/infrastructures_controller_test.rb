require 'test_helper'

class InfrastructuresControllerTest < ActionController::TestCase

  def setup
    stub_authentication

  end

  test 'get_infrastructure_credentials should return empty json if there is no credentials registered' do
    infrastructure_name = 'dummy'
    infrastructure = mock 'infrastructure' do
      stubs(:get_credentials).returns([])
    end
    InfrastructureFacadeFactory.stubs(:get_facade_for).with(infrastructure_name).returns(infrastructure)

    get :get_infrastructure_credentials, infrastructure: infrastructure_name, format: :json

    assert_response :success, response.body

    message = JSON.parse(response.body)
    assert_kind_of Array, message['data']
    assert_empty message['data']
  end

  test 'querying get_infrastructure_credentials with not white-listed params should cause security error' do
    infrastructure_name = 'dummy'
    credentials = [{'one' => 'two'}]
    infrastructure = mock 'infrastructure' do
      stubs(:get_credentials).returns(credentials)
    end
    InfrastructureFacadeFactory.stubs(:get_facade_for).with(infrastructure_name).returns(infrastructure)

    get :get_infrastructure_credentials, infrastructure: infrastructure_name,
        query_params: {'host'=>'localhost', 'bad'=>'one'}, format: :json

    assert_response 412, response.body
  end

  test 'querying get_infrastructure_credentials with non-string params should cause security error' do
    infrastructure_name = 'dummy'
    credentials = [{'one' => 'two'}]
    infrastructure = mock 'infrastructure' do
      stubs(:get_credentials).returns(credentials)
    end
    InfrastructureFacadeFactory.stubs(:get_facade_for).with(infrastructure_name).returns(infrastructure)

    get :get_infrastructure_credentials, infrastructure: infrastructure_name,
        query_params: {'host'=>{drop: 'database'}, {port: 1}=>1}, format: :json

    assert_response 412, response.body
  end

  test 'querying get_infrastructure_credentials with white-listed params should pass' do
    infrastructure_name = 'dummy'
    credentials = [{'one' => 'two'}]
    infrastructure = mock 'infrastructure' do
      stubs(:get_credentials).returns(credentials)
    end
    InfrastructureFacadeFactory.stubs(:get_facade_for).with(infrastructure_name).returns(infrastructure)

    get :get_infrastructure_credentials, infrastructure: infrastructure_name,
        query_params: {'host'=>'localhost', 'port'=>1}, format: :json

    assert_response :success, response.body

    message = JSON.parse(response.body)
    assert_kind_of Array, message['data']
    assert_equal credentials, message['data']
  end



end
