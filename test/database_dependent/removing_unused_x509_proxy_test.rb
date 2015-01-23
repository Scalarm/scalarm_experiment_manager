require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require_dependency 'plgrid/pl_grid_facade_factory'
require_dependency 'clouds/cloud_facade_factory'

class RemovingUnusedX509ProxyTest < MiniTest::Test

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}

    @su = ScalarmUser.new(login: 'user'); @su.save
    
    @plgrid = PlGridFacadeFactory.instance.get_facade('qsub')
    @gc = GridCredentials.new(user_id: @su.id, secret_proxy: '<this is secret proxy>'); @gc.save

    @plcloud = CloudFacadeFactory.instance.get_facade('pl_cloud')
    @cs = CloudSecrets.new(user_id: @su.id, cloud_name: 'pl_cloud', secret_proxy: '<this is secret proxy>'); @cs.save
  end

  def test_plgrid_removing_x509_proxy_grid
    # -- given -- scalarm user with credentials and two different jobs
    PlGridJob.new(user_id: @su.id, state: :error, scheduler_type: 'qsub').save
    PlGridJob.new(user_id: @su.id, state: :running, has_onsite_monitoring: true, scheduler_type: 'qcg').save
    PlGridJob.new(user_id: @su.id, state: :running, has_scheduler_type: 'glite').save

    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)

    # -- when
    @plgrid.destroy_unused_credentials(:x509_proxy, @su)


    # -- then
    assert_nil(GridCredentials.where(user_id: @su.id).first)
  end  

  def test_plgrid_not_removing_x509_proxy_due_to_user_session
    # -- given -- scalarm user with user session
    UserSession.new(session_id: @su.id, last_update: Time.now).save

    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)

    # -- when
    @plgrid.destroy_unused_credentials(:x509_proxy, @su)

    # -- then
    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)
  end

  def test_plgrid_not_removing_x509_proxy_due_to_monitored_job
    # -- given
    PlGridJob.new(user_id: @su.id, state: :running, scheduler_type: 'qsub').save

    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)

    # -- when
    @plgrid.destroy_unused_credentials(:x509_proxy, @su)

    # -- then
    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)
  end

  def test_plgrid_not_removing_x509_proxy_due_to_monitored_job_qcg
    # -- given
    PlGridJob.new(user_id: @su.id, state: :running, scheduler_type: 'qcg').save

    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)
    # -- when
    @plgrid.destroy_unused_credentials(:x509_proxy, @su)
    # -- then
    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)
  end  

  def test_plcloud_removing_x509_proxy
     # -- given -- scalarm user with credentials and two different jobs
     CloudVmRecord.new(user_id: @su.id, state: :error, cloud_name: 'pl_cloud').save
     CloudVmRecord.new(user_id: @su.id, state: :running, cloud_name: 'google').save

     refute_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first.secret_proxy)
     # -- when
     @plcloud.destroy_unused_credentials(:x509_proxy, @su)
     # -- then
     assert_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first)
  end

  def test_plcloud_not_removing_x509_proxy_due_to_user_session
     # -- given -- scalarm user with user session
     UserSession.new(session_id: @su.id, last_update: Time.now).save

     refute_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first.secret_proxy)
     # -- when
     @plcloud.destroy_unused_credentials(:x509_proxy, @su)
     # -- then
     refute_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first.secret_proxy)
  end

  def test_plcloud_removing_x509_proxy_due_to_not_valid_user_session
    # -- given -- scalarm user with user session
    UserSession.new(session_id: @su.id,
                    last_update: Time.now-Rails.configuration.session_threshold.seconds-10.minutes).save

    refute_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first.secret_proxy)
    # -- when
    @plcloud.destroy_unused_credentials(:x509_proxy, @su)
    # -- then
    assert_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first)
  end

  def test_plgrid_removing_x509_proxy_due_to_not_valid_user_session
    # -- given -- scalarm user with user session
    UserSession.new(session_id: @su.id,
                    last_update: Time.now-Rails.configuration.session_threshold.seconds-10.minutes).save

    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)
    # -- when
    @plgrid.destroy_unused_credentials(:x509_proxy, @su)
    # -- then
    assert_nil(GridCredentials.where(user_id: @su.id).first)
  end

  def test_plcloud_not_removing_x509_proxy_due_to_monitored_vm
     # -- given
     CloudVmRecord.new(user_id: @su.id, state: :running, cloud_name: 'pl_cloud').save

     refute_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first.secret_proxy)
     # -- when
     @plcloud.destroy_unused_credentials(:x509_proxy, @su)
     # -- then
     refute_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first.secret_proxy)
  end

  def test_user_removing_x509_proxy
    # -- given -- scalarm user with credentials and two different jobs
    PlGridJob.new(user_id: @su.id, state: :error, scheduler_type: 'qsub').save
    PlGridJob.new(user_id: @su.id, state: :running, has_onsite_monitoring: true, scheduler_type: 'qcg').save
    PlGridJob.new(user_id: @su.id, state: :running, scheduler_type: 'glite').save
    CloudVmRecord.new(user_id: @su.id, state: :error, cloud_name: 'pl_cloud').save
    CloudVmRecord.new(user_id: @su.id, state: :running, cloud_name: 'google').save

    refute_nil(GridCredentials.where(user_id: @su.id).first.secret_proxy)
    refute_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first.secret_proxy)
    # -- when
    @su.destroy_unused_credentials
    # -- then
    assert_nil(GridCredentials.where(user_id: @su.id).first)
    assert_nil(CloudSecrets.where(user_id: @su.id, cloud_name: 'pl_cloud').first)
  end

end