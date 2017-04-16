require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'

class InfrastructureViewTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super

    @user1 = ScalarmUser.new(login: 'test_user_1')
    @user1.password = 'user1'
    @user1.password_repeat = 'user1'
    @user1.save

    @user2 = ScalarmUser.new(login: 'test_user_2')
    @user2.password = 'user2'
    @user2.password_repeat = 'user2'
    @user2.save
  end

  def teardown
    super
  end

  test 'infrastructure#list should return facades visible for the given user' do
    # when a private cluster is defined by one user
    create_cluster_record

    open_session do |sess|
      # it should be visible by the owner
      sess.get list_infrastructure_path, {}, {
          'HTTP_ACCEPT' => 'application/json',
          'HTTP_AUTHORIZATION' =>
              ActionController::HttpAuthentication::Basic.encode_credentials('test_user_1', 'user1')
      }

      facades = JSON.parse(sess.response.body)
      clusters = facades.select {|facade| facade['group'] == 'clusters'}.first
      assert_equal 1, clusters['children'].size
    end

    open_session do |sess|
      # but it should not be visible by others
      sess.get list_infrastructure_path, {}, {
          'HTTP_ACCEPT' => 'application/json',
          'HTTP_AUTHORIZATION' =>
              ActionController::HttpAuthentication::Basic.encode_credentials('test_user_2', 'user2')
      }

      facades = JSON.parse(sess.response.body)
      clusters = facades.select {|facade| facade['group'] == 'clusters'}.first
      assert clusters['children'].blank?
    end
  end

  test 'infrastructure#list should show public clusters between users' do
    # when a public cluster is defined by one user
    create_cluster_record public: true

    # it should be visible by the owner
    open_session do |sess|
      sess.get list_infrastructure_path, {}, {
          'HTTP_ACCEPT' => 'application/json',
          'HTTP_AUTHORIZATION' =>
              ActionController::HttpAuthentication::Basic.encode_credentials('test_user_1', 'user1')
      }

      facades = JSON.parse(sess.response.body)
      clusters = facades.select {|facade| facade['group'] == 'clusters'}.first
      assert_equal 1, clusters['children'].size
    end

    # and it should be visible by another
    open_session do |sess|
      sess.get list_infrastructure_path, {}, {
          'HTTP_ACCEPT' => 'application/json',
          'HTTP_AUTHORIZATION' =>
              ActionController::HttpAuthentication::Basic.encode_credentials('test_user_2', 'user2')
      }

      facades = JSON.parse(sess.response.body)

      clusters = facades.select {|facade| facade['group'] == 'clusters'}.first
      assert_equal 1, clusters['children'].size
    end
  end

  private

  def create_cluster_record(public=false)
    record = ClusterRecord.new(
        name: "Zeus @ ACK Cyfronet AGH",
        scheduler: "pbs",
        host: "zeus.cyfronet.pl",
        created_by: @user1.id
    )

    if public
      record.public = true
    end

    record.save
  end

end