require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class CloudFacadeTest < MiniTest::Test

  require 'infrastructure_facades/infrastructure_errors'

  def test_schedule_invalid_credentials
    credentials = stub_everything 'credentials' do
      stubs(:invalid).returns(true)
    end
    cloud_client = stub_everything
    facade = CloudFacade.new(cloud_client)
    facade.stubs(:get_cloud_secrets).returns(credentials)

    assert_raises InfrastructureErrors::InvalidCredentialsError do
      facade.start_simulation_managers('u', 2, 'e')
    end
  end

  def test_resource_status_not_avail
    scheduler = stub_everything 'scheduler'
    scheduler_class = stub_everything 'scheduler_class' do
      stubs(:new).returns(scheduler)
    end
    record = stub_everything
    facade = PlGridFacade.new(scheduler_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session).raises(StandardError.new 'no ssh connection')

    status = facade._simulation_manager_resource_status(record)

    assert_equal :not_available, status
  end

  def test_resource_status_avail
    scheduler = stub_everything 'scheduler'
    scheduler_class = stub_everything 'scheduler_class' do
      stubs(:new).returns(scheduler)
    end
    record = stub_everything
    facade = PlGridFacade.new(scheduler_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :available, status
  end

  def test_resource_status_initializing
    scheduler = stub_everything 'scheduler' do
      stubs(:status).returns(:initializing)
    end
    scheduler_class = stub_everything 'scheduler_class' do
      stubs(:new).returns(scheduler)
    end
    record = stub_everything do
      stubs(:job_id).returns('job_1')
    end

    facade = PlGridFacade.new(scheduler_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session).returns(stub_everything)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :initializing, status
  end

  def test_resource_status_running
    scheduler = stub_everything 'scheduler' do
      stubs(:status).returns(:running)
    end
    scheduler_class = stub_everything 'scheduler_class' do
      stubs(:new).returns(scheduler)
    end
    record = stub_everything do
      stubs(:job_id).returns('job_1')
    end
    facade = PlGridFacade.new(scheduler_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :running_sm, status
  end

  def test_resource_status_released
    scheduler = stub_everything 'scheduler' do
      stubs(:status).returns(:deactivated)
    end
    scheduler_class = stub_everything 'scheduler_class' do
      stubs(:new).returns(scheduler)
    end
    record = stub_everything do
      stubs(:job_id).returns('job_1')
    end
    facade = PlGridFacade.new(scheduler_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :released, status
  end

end