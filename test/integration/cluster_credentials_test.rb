require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'

class ClusterCredentialsTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super
    @su = ScalarmUser.new(login: 'user')
    @su.password = 'pass'
    @su.save

    post login_path, username: @su.login, password: 'pass'

    @cr = ClusterRecord.new(name: "My cluster", scheduler: "slurm", host: "whatever.com", created_by: @su.id)
    @cr.save
  end

  def teardown
    super
  end

  test "submitting valid credentials should create proper cluster credentials record" do
    # -- given
    ClusterCredentials.any_instance.stubs(:valid?).returns(true)

    # -- when
    post add_infrastructure_credentials_infrastructure_path, {
      infrastructure_name: "cluster_#{@cr.id}",
      cluster_id: @cr.id,
      type: "password",
      login: "ble",
      password: "ble",
      password_repeat: "ble"
    }, { user: @su.id }

    # -- then
    assert_equal 1, ClusterCredentials.count
    assert_equal @cr.id, ClusterCredentials.first.cluster_id
    assert_equal @su.id, ClusterCredentials.first.owner_id
    assert_equal false, ClusterCredentials.first.invalid
  end

  test "submitting invalid credentials should create record with invalid set" do
    # -- given
    ClusterCredentials.any_instance.stubs(:valid?).returns(false)

    # -- when
    post add_infrastructure_credentials_infrastructure_path, {
      infrastructure_name: "cluster_#{@cr.id}",
      cluster_id: @cr.id,
      type: "password",
      login: "ble",
      password: "ble",
      password_repeat: "ble"
    }, { user: @su.id }

    # -- then
    assert_equal 1, ClusterCredentials.count
    assert_equal @cr.id, ClusterCredentials.first.cluster_id
    assert_equal @su.id, ClusterCredentials.first.owner_id
    assert_equal true, ClusterCredentials.first.invalid
  end

  test "submitting invalid credentials too many times should ban these credentials" do
    # -- given
    ClusterCredentials.any_instance.stubs(:valid?).returns(false)

    # -- when
    post add_infrastructure_credentials_infrastructure_path, {
      infrastructure_name: "cluster_#{@cr.id}",
      cluster_id: @cr.id,
      type: "password",
      login: "ble",
      password: "ble",
      password_repeat: "ble"
    }, { user: @su.id }

    # -- then
    assert_equal 1, ClusterCredentials.count
    assert_equal @cr.id, ClusterCredentials.first.cluster_id
    assert_equal @su.id, ClusterCredentials.first.owner_id
    assert_equal true, ClusterCredentials.first.invalid


    assert_equal "error", JSON.parse(@response.body)["status"]
    assert_equal "invalid", JSON.parse(@response.body)["error_code"]

    post add_infrastructure_credentials_infrastructure_path, {
      infrastructure_name: "cluster_#{@cr.id}",
      cluster_id: @cr.id,
      type: "password",
      login: "ble",
      password: "ble",
      password_repeat: "ble"
    }, { user: @su.id }

    assert_equal "error", JSON.parse(@response.body)["status"]
    assert_equal "invalid", JSON.parse(@response.body)["error_code"]

    post add_infrastructure_credentials_infrastructure_path, {
      infrastructure_name: "cluster_#{@cr.id}",
      cluster_id: @cr.id,
      type: "password",
      login: "ble",
      password: "ble",
      password_repeat: "ble"
    }, { user: @su.id }

    assert_equal "error", JSON.parse(@response.body)["status"]
    assert_equal "banned", JSON.parse(@response.body)["error_code"]

    post add_infrastructure_credentials_infrastructure_path, {
      infrastructure_name: "cluster_#{@cr.id}",
      cluster_id: @cr.id,
      type: "password",
      login: "ble",
      password: "ble",
      password_repeat: "ble"
    }, { user: @su.id }

    assert_equal "error", JSON.parse(@response.body)["status"]
    assert_equal "banned", JSON.parse(@response.body)["error_code"]
  end

end
