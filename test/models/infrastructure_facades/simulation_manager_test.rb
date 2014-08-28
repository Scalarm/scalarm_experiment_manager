require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/simulation_manager'

class SimulationManagerTest < MiniTest::Test

  def setup
    record = stub_everything do
      stubs(:experiment).returns(stub_everything)
    end
    @sm = SimulationManager.new(record, stub_everything)
  end

  METHOD_NAMES = [
      :name,
      :monitor,
      :stop,
      :restart,
      :resource_status,
      :get_log,
      :install,
      :prepare_resource
  ]

  def test_has_methods
    mock_record = stub_everything
    mock_record.stubs(:id).returns('id')
    mock_record.stubs(:max_init_time).returns(1)

    mock_infrastructure = stub_everything
    mock_infrastructure.stubs(:short_name).returns('anything')

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)

    METHOD_NAMES.each do |method_name|
      assert_respond_to simulation_manager, method_name
    end
  end

  def test_all_cases_are_used
    record = stub_everything 'record'
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)

    assert_empty sm.monitoring_cases.keys - sm.monitoring_order
  end

  def test_delegation
    mock_record = stub_everything('record')
    mock_infrastructure = mock('infrastructure') do
      stubs(:short_name).returns('...')
      SimulationManager::DELEGATES.each do |delegate|
        expects("_simulation_manager_#{delegate}").with(mock_record).once
      end
      expects('_simulation_manager_wrong').with(mock_record).never
    end
    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    SimulationManager.any_instance.stubs(:generate_monitoring_cases).returns(nil)
    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)

    SimulationManager::DELEGATES.each do |delegate|
      assert_respond_to simulation_manager, delegate
      simulation_manager.send(delegate, mock_record)
    end

    assert (not simulation_manager.respond_to? :wrong)
    assert_raises(NoMethodError) {simulation_manager.wrong}
  end

  def test_no_experiment
    record = stub_everything 'record' do
      stubs(:experiment).returns(nil)
      stubs(:state)
      expects(:destroy)
    end

    infrastructure = stub_everything

    sm = SimulationManager.new(record, infrastructure)
    sm.expects(:stop)

    sm.monitor
  end

  def test_no_experiment_exception
    record = stub_everything 'record' do
      stubs(:experiment).returns(nil)
      stubs(:state)
      expects(:destroy)
    end

    infrastructure = stub_everything
    infrastructure.stubs(:_simulation_manager_stop).raises(StandardError.new('err'))

    sm = SimulationManager.new(record, infrastructure)
    sm.expects(:stop)

    sm.monitor
  end

  def test_set_terminating_state_after_stop
    @sm.expects(:set_state).with(:terminating).once

    @sm.stop
  end

  def test_monitoring_stopping
    record = stub_everything 'record' do
      stubs(:stopping_time_exceeded?).returns(false)
      stubs(:experiment).returns(stub_everything)
    end
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)
    sm.stubs(:resource_status).returns(:running_sm)
    sm.stubs(:state).returns(:terminating)
    sm.expects(:stop).never

    sm.monitor
  end

  def test_monitoring_stopping_repeat
    record = stub_everything 'record' do
      stubs(:stopping_time_exceeded?).returns(true, false)
      stubs(:experiment).returns(stub_everything)
    end
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)
    sm.stubs(:resource_status).returns(:running_sm)
    sm.stubs(:state).returns(:terminating)
    sm.expects(:stop).once

    # first monitor invoke - should get stopping_time_exceeded == true, so it should invoke stop
    sm.monitor
    # next invocation should not invoke stop
    sm.monitor
  end

  def test_monitoring_destroy_after_stopping
    record = stub_everything 'record' do
      expects(:destroy).once
      stubs(:experiment).returns(stub_everything)
    end
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)
    sm.stubs(:resource_status).returns(:released)
    sm.stubs(:state).returns(:terminating)
    sm.expects(:stop).never

    sm.monitor
  end

  def test_state_delegator
    state = mock 'state'
    record = stub_everything 'record' do
      stubs(:state).returns(state)
    end
    infrastructure = stub_everything
    sm = SimulationManager.new(record, infrastructure)

    sm_state = sm.state

    assert_equal state, sm_state

  end

  def test_created_prepare_resource
    @sm.stubs(:state).returns(:created)
    @sm.stubs(:resource_status).returns(:available)

    @sm.expects(:prepare_resource).once
    @sm.expects(:set_state).with(:initializing).once

    @sm.monitor
  end

  def test_initializing_init_time_exceeded
    @sm.stubs(:state).returns(:initializing)
    @sm.stubs(:resource_status).returns(:available)
    @sm.stubs(:init_time_exceeded?).returns(true)

    @sm.expects(:restart).once
    @sm.expects(:set_state).with(:initializing).once

    @sm.monitor
  end

  def test_initializing_install
    @sm.stubs(:state).returns(:initializing)
    @sm.stubs(:resource_status).returns(:ready)

    @sm.expects(:install).once
    @sm.expects(:set_state).with(:running).once

    @sm.monitor
  end

  def test_initializing_detect_running_sm
    @sm.stubs(:state).returns(:initializing)
    @sm.stubs(:resource_status).returns(:running_sm)

    @sm.expects(:set_state).with(:running).once

    @sm.monitor
  end

  def test_running_time_limit_exceeded
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:running_sm)
    @sm.stubs(:time_limit_exceeded?).returns(true)

    @sm.expects(:stop).once
    @sm.expects(:set_state).with(:terminating).once

    @sm.monitor
  end

  def test_terminated_untimely
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:released)
    @sm.stubs(:should_not_be_already_terminated?).returns(true)

    @sm.expects(:store_terminated_error).once

    @sm.monitor
  end

  def test_wait_on_initializing
    @sm.stubs(:state).returns(:initializing)
    @sm.stubs(:resource_stateus).returns(:initializing)
    @sm.stubs(:should_not_be_already_terminated?).returns(true)

    @sm.expects(:store_terminated_error).never

    @sm.monitor
  end

  # On changing state to ERROR, stop should be invoked when resource was tried to acquire
  def test_stop_on_set_error_state
    SimulationManagerRecord::POSSIBLE_STATES.each do |state|
      [:initializing, :ready, :running_sm].each do |resource_state|
        @sm.stubs(:state).returns(state)
        @sm.stubs(:resource_status).returns(resource_state)

        @sm.expects(:stop).at_least_once

        @sm.set_state(:error)
      end
    end
  end

  def test_monitoring_resource_error
    (SimulationManagerRecord::POSSIBLE_STATES - [:error]).each do |state|
      @sm.stubs(:state).returns(state)
      @sm.stubs(:resource_status).returns(:error)

      @sm.expects(:store_error_resource_status).once

      @sm.monitor
    end
  end

  def test_infrastructure_stop_action
    @sm.infrastructure.expects(:_simulation_manager_stop).once
    @sm.expects(:set_state).with(:terminating).once

    @sm.stop
  end

  def test_sm_action_no_credentials
    action = mock 'action'
    @sm.stubs(:delegate_to_infrastructure).with(action).raises(InfrastructureErrors::NoCredentialsError)

    @sm.record.expects(:store_no_credentials)
    @sm.record.expects(:clear_no_credentials).never

    assert_raises InfrastructureErrors::NoCredentialsError do
      @sm.infrastructure_action(action)
    end
  end

  def test_before_init_no_credentials
    @sm.stubs(:before_monitor).raises(InfrastructureErrors::NoCredentialsError)

    @sm.record.expects(:store_no_credentials).at_least_once
    @sm.record.expects(:clear_no_credentials).never

    @sm.monitor
  end

  def test_clear_no_credentials
    @sm.record.expects(:clear_no_credentials)
    @sm.monitor
  end

  def test_should_not_be_already_terminated?

  end

end