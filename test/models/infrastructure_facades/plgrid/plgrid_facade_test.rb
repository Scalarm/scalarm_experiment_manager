require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'mocha/parameter_matchers'

class PlGridFacadeTest < MiniTest::Test
  require 'infrastructure_facades/infrastructure_errors'

  def setup
    @scheduler = stub_everything 'scheduler'
    @scheduler_class = stub_everything 'scheduler_class'
    @facade = PlGridFacade.new(@scheduler_class)
    @facade.stubs(:scheduler).returns(@scheduler)
  end

  def test_schedule_invalid_credentials
    user_id = mock 'user_id'
    instances_count = mock 'instances_count'
    experiment_id = mock 'experiment_id'
    credentials = stub_everything 'credentials' do
      stubs(:invalid).returns(true)
      stubs(:password).returns('password')
    end
    scheduler = stub_everything 'scheduler'
    facade = PlGridFacade.new(scheduler)
    InfrastructureFacade.stubs(:prepare_simulation_manager_package)
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
    record = stub_everything 'record' do
      stubs(:validate_credentials).raises(InfrastructureErrors::InvalidCredentialsError)
    end

    assert_raises InfrastructureErrors::InvalidCredentialsError do
      @facade.validate_credentials_for(record)
    end
  end

  def test_valid_credentials_available_true
    user_id = stub_everything 'user_id'
    credentials = stub_everything 'credentials' do
      stubs(:invalid).returns(false)
      stubs(:secret_proxy).returns(true)
    end
    GridCredentials.stubs(:find_by_user_id).with(user_id).returns(credentials)

    assert @facade.valid_credentials_available?(user_id)
  end

  def test_enabled_with_monitoring
    user_id = stub_everything 'user_id'

    @scheduler.stubs(:onsite_monitorable?).returns(true)
    @facade.stubs(:valid_credentials_available?).returns(false)

    assert @facade.enabled_for_user?(user_id)
  end

  def test_enabled_with_credentials
    user_id = stub_everything 'user_id'

    @scheduler.stubs(:onsite_monitorable?).returns(false)
    @facade.stubs(:valid_credentials_available?).returns(true)

    assert @facade.enabled_for_user?(user_id)
  end

  def test_enabled_false
    user_id = stub_everything 'user_id'

    @scheduler.stubs(:onsite_monitorable?).returns(false)
    @facade.stubs(:valid_credentials_available?).returns(false)

    refute @facade.enabled_for_user?(user_id)
  end

  ## TODO: this test is old and buggy but functionality works - consider rewrite
  # def test_start_simulation_managers
  #   skip 'TODO - mocks are incorrectly configured'
  #   user_id = mock 'user_id'
  #   instances_count = mock 'instances_count'
  #   experiment_id = mock 'experiment_id'
  #   login = mock('plgrid_login')
  #   password = mock('password')
  #   additional_params = {
  #       onsite_monitoring: true,
  #       plgrid_login: login,
  #       password: password
  #   }
  #   temp_credentials = stub_everything 'temp_credentials' do
  #     stubs(:login).returns(login)
  #     stubs(:password).returns(password)
  #   end
  #
  #   InfrastructureFacade.stubs(:prepare_simulation_manager_package)
  #   InfrastructureFacade.stubs(:send_and_launch_onsite_monitoring)
  #   InfrastructureFacade.stubs(:using_temp_credentials?).with(additional_params).returns(true)
  #   InfrastructureFacade.stubs(:create_temp_credentials).with(additional_params).returns(temp_credentials)
  #   @facade.stubs(:create_records)
  #
  #   @facade.start_simulation_managers(user_id, instances_count, experiment_id, additional_params)
  # end

  def test_create_temp_credentials_proxy
    require 'scalarm/service_core/grid_proxy'

    proxy_s = 'zxc'
    username_s = 'user1'

    proxy_mock = mock 'proxy' do
      stubs(:username).returns(username_s)
    end

    creds_mock = mock 'credentials' do
      expects(:secret_proxy=).with(proxy_s)
    end

    GridCredentials.expects(:new).
        with(has_entry(login: username_s)).
        returns(creds_mock)

    Scalarm::ServiceCore::GridProxy::Proxy.stubs(:new).with(proxy_s).returns(proxy_mock)

    assert_equal creds_mock, PlGridFacade.create_temp_credentials(proxy: proxy_s)
  end

end