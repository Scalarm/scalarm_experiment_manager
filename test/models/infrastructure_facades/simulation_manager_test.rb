require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'active_support/testing/declarative'

require 'infrastructure_facades/simulation_manager'

class SimulationManagerTest < MiniTest::Test

  extend ActiveSupport::Testing::Declarative

  def setup
    @simulation_runs = stub_everything 'simulation_runs'
    @experiment = stub_everything 'experiment'
    @experiment.stubs(:simulation_runs).returns(@simulation_runs)

    @record = stub_everything 'record'
    @record.stubs(:experiment).returns(@experiment)

    @sm = SimulationManager.new(@record, stub_everything)

    # NOTICE
    # by default in this test, there are tasks waiting
    @sm.stubs(:no_pending_tasks?).returns(false)

    # no test should accept errors by default
    @sm.logger.expects(:error).never
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
      stubs(:experiment).returns(stub_everything)
    end

    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)
    sm.stubs(:resource_status).returns(:released)
    sm.stubs(:state).returns(:terminating)
    sm.expects(:stop).never

    sm.expects(:destroy_record).once

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
    @sm.stubs(:resource_status).returns(:initializing)
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
    @sm.stubs(:should_be_running?).returns(true)

    @sm.expects(:store_terminated_error).once

    @sm.monitor
  end

  def test_wait_on_initializing
    @sm.stubs(:state).returns(:initializing)
    @sm.stubs(:resource_status).returns(:initializing)
    @sm.stubs(:should_be_running?).returns(true)

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

  def test_static_running_but_ready
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:ready)
    @sm.stubs(:should_be_running?).returns(true)

    @sm.expects(:store_terminated_error).once

    @sm.monitor
  end

  def test_monitoring_onsite
    @record.stubs(:onsite_monitoring).returns(true)
    @record.expects(:store_no_credentials).never
    @sm.stubs(:state).returns(:created)
    @sm.stubs(:try_all_monitoring_cases)

    @sm.monitor
  end

  def test_infrastructure_action_general
    @record.stubs(:onsite_monitoring).returns(true)
    @sm.stubs(:general_action).with('action').returns('something')
    @sm.expects(:delegate_to_infrastructure).with('action').never

    assert_equal 'something', @sm.infrastructure_action('action')
  end

  def test_infrastructure_action_delegated
    @record.stubs(:onsite_monitoring).returns(true)
    @sm.stubs(:general_action).with('action').returns(nil)
    @sm.stubs(:delegate_to_infrastructure).with('action').returns('something')
    @sm.expects(:delegate_to_infrastructure).with('action').never

    assert_equal 'something', @sm.infrastructure_action('action')
  end

  ##
  # When onsite_monitoring flag is set
  # Then resource_status should be read from record attribute
  def test_onsite_resource_status_read
    res_status = 'stored_status'

    @record.stubs(:onsite_monitoring).returns(true)
    @record.stubs(:resource_status).returns(res_status)

    assert_equal res_status, @sm.resource_status
  end

  ##
  # When onsite_monitoring flag is false
  # Then resource_status should be read from infrastructure
  def test_delegated_resource_status_read
    res_status = 'some_status'

    @record.stubs(:onsite_monitoring).returns(false)
    @sm.infrastructure.stubs(:_simulation_manager_resource_status).returns(res_status)

    assert_equal res_status, @sm.resource_status
  end

  ##
  # When SiM is INITIALIZING and resource is back to AVAILABLE
  # there should be error reported
  def test_available_and_initializing
    @sm.stubs(:state).returns(:initializing)
    @sm.stubs(:resource_status).returns(:available)

    @sm.expects(:set_state).with(:error)

    @sm.monitor
  end

  ##
  # When SiM is TERIMNATING and resource is back between NOT_AVAILABLE and READY
  # there should be error reported
  def test_ready_and_terminating
    [:not_available, :available, :initializing, :ready].each do |rstate|
      @sm.stubs(:state).returns(:terminating)
      @sm.stubs(:resource_status).returns(rstate)

      @sm.expects(:set_state).with(:error)

      @sm.monitor
    end
  end

  ##
  # When SiM is initializing (or later) and there
  # is no resource id yet, it should be error
  def test_initializing_without_resource_id
    @sm.stubs(:state).returns(:created)
    @sm.stubs(:resource_status).returns(:initializing)

    @sm.expects(:set_state).with(:error)

    @sm.monitor
  end

  def test_monitoring_created_available_wo_cmd
    cmd_code = 'some'
    cmd_cmd = 'some_exec'

    @sm.stubs(:state).returns(:created)
    @sm.stubs(:resource_status).returns(:available)

    @sm.expects(:effect_pass).never
    @sm.expects(:prepare_resource)

    @sm.monitor
  end

  def test_monitoring_on_command_delegation_pass
    cmd_code = 'some'
    cmd_cmd = 'some_exec'

    @sm.stubs(:state).returns(:created)
    @sm.stubs(:resource_status).returns(:available)

    @record.stubs(:cmd_to_execute_code).returns(cmd_code)
    @record.stubs(:cmd_to_execute).returns(cmd_cmd)

    @sm.expects(:effect_pass)
    @sm.expects(:prepare_resource).never

    @sm.monitor
  end

  def test_monitoring_cmd_delegation_timeout
    @sm.stubs(:state).returns(:initializing)
    @sm.stubs(:resource_status).returns(:available)
    @sm.stubs(:cmd_delegated_on_site?).returns(true)
    @record.stubs(:cmd_delegation_time_exceeded?).returns(true)

    @sm.expects(:effect_pass).never
    @sm.expects(:error_cmd_delegation_timed_out)

    @sm.monitor
  end

  def test_created_timeout_not_on_site
    @sm.stubs(:state).returns(:created)
    @sm.stubs(:resource_status).returns(:not_available)
    @sm.stubs(:on_site_creation_timed_out?).returns(false)

    @sm.expects(:error_created_on_site_timed_out).never

    @sm.monitor
  end

  def test_created_on_site_timeout
    @sm.stubs(:state).returns(:created)
    @sm.stubs(:resource_status).returns(:not_available)
    @sm.stubs(:cmd_delegated_on_site?).returns(false)
    @sm.stubs(:on_site_creation_timed_out?).returns(true)

    @sm.expects(:error_created_on_site_timed_out)

    @sm.monitor
  end

end