require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/pl_grid_scheduler_base'
require 'net/ssh'

class ClusterRemoteWorkerDelegateTest < MiniTest::Test

  def setup
    @scheduler = mock()
    @sm_record = mock()
    @sm_record.stubs(:save)
    @sm_record.stubs(:validate)
    @sm_record.stubs(:error_log=)
    @sm_record.stubs(:credentials).returns({})
    @sm_record.stubs(:user_id)
    @sm_record.stubs(:experiment_id)
    @sm_record.stubs(:start_at)

    @ssh = stub_everything('ssh_session')
    @cluster_facade = mock()

    @delegate = ClusterRemoteWorkerDelegate.new(@scheduler)
    @delegate.cluster_facade = @cluster_facade
  end

  def test_exception_handling_in_resource_status_check
    @cluster_facade.stubs(:shared_ssh_session).raises(StandardError)

    assert_equal :not_available, @delegate.resource_status(@sm_record)
  end

  def test_resource_status_translation_from_initializing
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:job_identifier).returns('id')
    @scheduler.stubs(:status).returns(:initializing)

    assert_equal :initializing, @delegate.resource_status(@sm_record)
  end

  def test_resource_status_translation_from_running
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:job_identifier).returns('id')
    @scheduler.stubs(:status).returns(:running)

    assert_equal :running_sm, @delegate.resource_status(@sm_record)
  end

  def test_resource_status_translation_from_deactivated
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:job_identifier).returns('id')
    @scheduler.stubs(:status).returns(:deactivated)

    assert_equal :released, @delegate.resource_status(@sm_record)
  end

  def test_resource_status_translation_from_error
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:job_identifier).returns('id')
    @scheduler.stubs(:status).returns(:error)

    assert_equal :released, @delegate.resource_status(@sm_record)
  end

  def test_resource_status_translation_from_not_handled
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:job_identifier).returns('id')
    @scheduler.stubs(:status).returns(:not_handled)

    assert_equal :error, @delegate.resource_status(@sm_record)
  end

  def test_resource_status_which_raises_error
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:job_identifier).raises(StandardError)

    assert_equal :error, @delegate.resource_status(@sm_record)
  end

  def test_resource_status_without_job_id
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:job_identifier).returns(nil)

    assert_equal :available, @delegate.resource_status(@sm_record)
  end

  def test_prepare_resource_where_ssh_raises_exception
    @cluster_facade.stubs(:shared_ssh_session).raises(StandardError)
    @sm_record.stubs(:user_id).returns('id')

    @sm_record.expects(:store_error)

    @delegate.prepare_resource(@sm_record)
  end

  def test_prepare_resource_where_ssh_raises_authentication_error
    @cluster_facade.stubs(:shared_ssh_session).raises(Net::SSH::AuthenticationFailed)
    @sm_record.stubs(:user_id).returns('id')

    @sm_record.expects(:store_error)

    @delegate.prepare_resource(@sm_record)
  end

  def test_prepare_resource_where_submit_job_raises_error
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @sm_record.stubs(:sm_uuid).returns('sm_uuid')
    @scheduler.stubs(:submit_job).raises(JobSubmissionFailed)
    SSHAccessedInfrastructure.stubs(:create_remote_directories)
    InfrastructureFacade.stubs(:prepare_simulation_manager_package)

    @sm_record.expects(:store_error)

    @delegate.prepare_resource(@sm_record)
  end

  def test_prepare_resource_where_everything_is_ok
    @cluster_facade.stubs(:shared_ssh_session).returns(@ssh)
    @scheduler.stubs(:submit_job)
    @sm_record.stubs(:sm_uuid).returns('sm_uuid')
    SSHAccessedInfrastructure.stubs(:create_remote_directories)
    InfrastructureFacade.stubs(:prepare_simulation_manager_package)
    @sm_record.stubs(:job_identifier=)

    @delegate.prepare_resource(@sm_record)
  end

end
