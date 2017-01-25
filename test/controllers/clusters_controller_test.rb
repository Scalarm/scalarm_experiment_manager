require 'test_helper'
require 'db_helper'

class ClustersControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super
    stub_authentication
    @controller.instance_variable_set(:@current_user, @user)
  end

  def teardown
    super
  end

  test 'create should create a new cluster record based on the given data' do
    post :create, name: 'example', scheduler: 'slurm', host: 'head.node.com', format: 'json'

    assert_response :success
    cluster = JSON.parse(response.body)
    assert_equal 'example', cluster['name']
    assert_equal 'head.node.com', cluster['host']
    assert_equal 'slurm', cluster['scheduler']
  end

  test 'index should return a list of existing cluster records visible for the logged in user' do
    ClusterRecord.new(name: 'rec1', scheduler: 'slurm', host: 'somewhere1.com', public: false, created_by: @user.id).save
    ClusterRecord.new(name: 'rec2', scheduler: 'slurm', host: 'somewhere2.com', public: false, created_by: @user.id).save
    ClusterRecord.new(name: 'rec3', scheduler: 'pbs', host: 'somewhere3.com', public: false, created_by: @user.id).save
    ClusterRecord.new(name: 'rec4', scheduler: 'pbs', host: 'somewhere4.com', public: false, created_by: BSON::ObjectId.new).save
    ClusterRecord.new(name: 'rec5', scheduler: 'pbs', host: 'somewhere5.com', public: true, created_by: BSON::ObjectId.new).save

    get :index, format: 'json'

    assert_response :success
    clusters = JSON.parse(response.body)
    assert_equal 4, clusters.size
  end

  test 'destroy should remove existing cluster record from database' do
    record = ClusterRecord.new(name: 'rec1', scheduler: 'slurm', host: 'somewhere1.com', public: false, created_by: @user.id).save

    delete :destroy, id: record.id.to_s, format: 'json'

    assert_response :success
  end

  test 'destroy on non existing record should return not_found' do
    ClusterRecord.new(name: 'rec1', scheduler: 'slurm', host: 'somewhere1.com', public: false, created_by: @user.id).save

    delete :destroy, id: BSON::ObjectId.new, format: 'json'

    assert_response :not_found
  end

  test 'destroy on non visible record should return not_found' do
    record = ClusterRecord.new(name: 'rec1', scheduler: 'slurm', host: 'somewhere1.com', public: false, created_by: BSON::ObjectId.new).save

    delete :destroy, id: record.id, format: 'json'

    assert_response :not_found
  end

  test 'credentials should return existing credentials to a cluster' do
    cluster = ClusterRecord.new(name: 'rec1', scheduler: 'slurm', host: 'somewhere1.com', public: false, created_by: @user.id).save
    ClusterCredentials.new(owner_id: @user.id, cluster_id: cluster.id, type: "password").save

    get :credentials, format: 'json'

    assert_response :success
  end
end
