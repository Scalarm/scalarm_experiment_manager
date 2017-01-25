require 'test_helper'
require 'sidekiq/testing'
require 'db_helper'

class InfrastructuresControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super
    stub_authentication
    Sidekiq::Testing.fake!
  end

  def teardown
    super
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

    get :get_infrastructure_credentials, infrastructure: infrastructure_name, query_params: {'host'=>'localhost', 'bad'=>'one'}, format: :json

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

  test 'scheduling sim on a cluster with onsite monitoring should create SendOnsiteMonitoringWorker' do
    credentials = mock 'credentials' do
      stubs(:valid?).returns(true)
      stubs(:id).returns("fake")
    end
    cluster_record = mock 'cluster_record' do
      stubs(:id).returns('fake')
      stubs(:name).returns('name')
    end
    scheduler = mock 'scheduler' do
      stubs(:short_name).returns('name')
    end

    InfrastructuresController.any_instance.stubs(:validate_experiment)
    ClusterFacade.any_instance.stubs(:load_or_create_credentials).returns(credentials)
    InfrastructureFacadeFactory.stubs(:get_facade_for).with("fake_cluster").returns(ClusterFacade.new(cluster_record, scheduler))


    SendOnsiteMonitoringWorker.expects(:perform_async).once

    post :schedule_simulation_managers, infrastructure_name: "fake_cluster", experiment_id: BSON::ObjectId.new.to_s,
         job_counter: "1", time_limit: 10, onsite_monitoring: true, format: :json

    assert_equal 1, JobRecord.all.to_a.size
    assert_equal 'ok', JSON.parse(response.body)['status']
    assert_equal 1, JSON.parse(response.body)['records_ids'].size
  end

  test 'scheduling sim on a plgrid with onsite monitoring should create SendOnsiteMonitoringWorker' do
    credentials = mock 'credentials' do
      stubs(:invalid).returns(false)
      stubs(:password).returns("fake_pass")
      stubs(:id).returns("fake")
    end

    InfrastructuresController.any_instance.stubs(:validate_experiment)
    GridCredentials.stubs(:find_by_user_id).returns(credentials)

    SendOnsiteMonitoringWorker.expects(:perform_async).once

    post :schedule_simulation_managers, infrastructure_name: "qcg", experiment_id: BSON::ObjectId.new.to_s,
         job_counter: "1", time_limit: 10, onsite_monitoring: true, format: :json

    assert_equal 1, PlGridJob.all.to_a.size
    assert_equal 'ok', JSON.parse(response.body)['status']
    assert_equal 1, JSON.parse(response.body)['records_ids'].size
  end

end
