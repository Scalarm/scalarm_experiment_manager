require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class PlGridFacadeTest < MiniTest::Test
  require 'infrastructure_facades/infrastructure_errors'

  def setup
    scheduler = stub_everything
    @facade = PlGridFacade.new(scheduler)
  end

  def test_schedule_invalid_credentials
    user_id = mock 'user_id'
    instances_count = mock 'instances_count'
    experiment_id = mock 'experiment_id'
    credentials = stub_everything 'credentials' do
      stubs(:invalid).returns(true)
    end
    scheduler = stub_everything 'scheduler'
    facade = PlGridFacade.new(scheduler)
    InfrastructureFacade.stubs(:prepare_configuration_for_simulation_manager)
    GridCredentials.stubs(:find_by_user_id).with(user_id).returns(credentials)

    assert_raises InfrastructureErrors::InvalidCredentialsError do
      facade.start_simulation_managers(user_id, instances_count, experiment_id)
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

  def test_validate_credentials_for
    record = stub_everything do
      stubs(:has_usable_credentials?).returns(false)
    end

    assert_raises InfrastructureErrors::NoCredentialsError do
      @facade.validate_credentials_for(record)
    end
  end

end