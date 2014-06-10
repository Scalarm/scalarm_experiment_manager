require 'test/unit'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/simulation_manager'

class SimulationManagerTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  METHOD_NAMES = [
      :name,
      :monitor,
      :stop,
      :restart,
      :running?,
      :resource_status,
      :get_log,
      :install
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

  def test_monitor_nothing
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-vm')
      expects(:time_limit_exceeded?).returns(false).once
      expects(:destroy).never
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      stubs(:max_init_time).returns(20.minutes)
      expects(:sm_initialized=).never
      expects(:save).never
      stubs(:experiment).returns(stub_everything)
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:sm_terminated?).returns(false).once
    simulation_manager.expects(:should_initialize_sm?).returns(false).once
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:install).never
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end

  def test_monitor_time_limit
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-vm')
      stubs(:error).returns(nil)
      stubs(:max_init_time).returns(20) # used for logger message
      expects(:time_limit_exceeded?).returns(true).once
      expects(:experiment_end?).never
      expects(:init_time_exceeded?).never
      expects(:sm_initialized=).never
      expects(:save).never
      stubs(:experiment).returns(stub_everything)
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:stop).once
    simulation_manager.expects(:sm_terminated?).never
    simulation_manager.expects(:should_initialize_sm?).never
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:install).never
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end

  def test_monitor_experiment_end
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-vm')
      stubs(:max_init_time).returns(20) # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(true).once
      expects(:init_time_exceeded?).never
      expects(:sm_initialized=).never
      expects(:save).never
      stubs(:experiment).returns(stub_everything)
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:stop).once
    simulation_manager.expects(:sm_terminated?).never
    simulation_manager.expects(:should_initialize_sm?).never
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:install).never
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end

  def test_monitor_init_time_exceeded
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-vm')
      stubs(:max_init_time).returns(20) # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(true).once
      expects(:sm_initialized_at=).once
      expects(:save).once
      stubs(:experiment).returns(stub_everything)
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
      expects(:simulation_manager_running?).never
      expects(:simulation_manager_install).never
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:restart).once
    simulation_manager.expects(:stop).never
    simulation_manager.expects(:sm_terminated?).never
    simulation_manager.expects(:should_initialize_sm?).never
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:install).never
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end

  def test_monitor_sm_terminated
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-vm')
      stubs(:max_init_time).returns(20) # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      expects(:sm_initialized=).never
      stubs(:experiment).returns(stub_everything)
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:record_init_time_exceeded).never
    simulation_manager.expects(:restart).never
    simulation_manager.expects(:stop).never
    simulation_manager.expects(:sm_terminated?).returns(true).once
    simulation_manager.expects(:should_initialize_sm?).never
    simulation_manager.expects(:record_sm_failed).once
    simulation_manager.expects(:install).never
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end

  def test_monitor_try_to_initialize_sm
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-vm')
      stubs(:max_init_time).returns(20) # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      expects(:sm_initialized=).with(true).once
      expects(:save).once
      stubs(:experiment).returns(stub_everything)
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:record_init_time_exceeded).never
    simulation_manager.expects(:restart).never
    simulation_manager.expects(:stop).never
    simulation_manager.expects(:sm_terminated?).returns(false).once
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:should_initialize_sm?).returns(true).once
    simulation_manager.expects(:install).with(mock_record).once
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end

  def test_should_initialize_sm_already_init
    record = stub_everything 'record' do
      expects(:state).returns(:initialized).at_least_once
    end

    infrastructure = stub_everything

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)
    simulation_manager = SimulationManager.new(record, infrastructure)
    simulation_manager.expects(:resource_status).never

    refute simulation_manager.should_initialize_sm?
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
      assert_nothing_raised do
        simulation_manager.send(delegate, mock_record)
      end
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

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)
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

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)
    infrastructure = stub_everything
    infrastructure.stubs(:_simulation_manager_stop).raises(StandardError.new('err'))

    sm = SimulationManager.new(record, infrastructure)
    sm.expects(:stop)

    sm.monitor
  end

  def test_terminating_state_after_stop
    record = stub_everything 'record' do
      expects(:set_stop).once
    end
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)

    sm.stop
  end

  def test_monitoring_stopping
    record = stub_everything 'record' do
      stubs(:state).returns(:terminating)
      stubs(:stopping_time_exceeded?).returns(false)
      stubs(:experiment).returns(stub_everything)
    end
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)
    sm.stubs(:resource_status).returns(:running)
    sm.expects(:stop).never

    sm.monitor
  end

  def test_monitoring_stopping_repeat
    record = stub_everything 'record' do
      stubs(:state).returns(:terminating)
      stubs(:stopping_time_exceeded?).returns(true, false)
      stubs(:experiment).returns(stub_everything)
    end
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)
    sm.stubs(:resource_status).returns(:running)
    sm.expects(:stop).once

    # first monitor invoke - should get stopping_time_exceeded == true, so it should invoke stop
    sm.monitor
    # next invocation should not invoke stop
    sm.monitor
  end

  def test_monitoring_destroy_after_stopping
    record = stub_everything 'record' do
      stubs(:state).returns(:terminating)
      expects(:destroy).once
      stubs(:experiment).returns(stub_everything)
    end
    infrastructure = stub_everything 'infrastructure'

    sm = SimulationManager.new(record, infrastructure)
    sm.stubs(:resource_status).returns(:deactivated)
    sm.expects(:stop).never

    sm.monitor
  end

end