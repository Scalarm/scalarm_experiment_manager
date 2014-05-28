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
      expects(:max_init_time).returns(20).once # used for logger message
      expects(:time_limit_exceeded?).returns(true).once
      expects(:experiment_end?).never
      expects(:init_time_exceeded?).never
      expects(:sm_initialized=).never
      expects(:save).never
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:destroy_with_record).once
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
      expects(:max_init_time).returns(20).once # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(true).once
      expects(:init_time_exceeded?).never
      expects(:sm_initialized=).never
      expects(:save).never
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:destroy_with_record).once
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
      expects(:max_init_time).returns(20).once # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(true).once
      expects(:sm_initialized=).never
      expects(:save).never
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
    simulation_manager.expects(:destroy_with_record).never
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
      expects(:max_init_time).returns(20).once # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      expects(:sm_initialized=).never
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:record_init_time_exceeded).never
    simulation_manager.expects(:restart).never
    simulation_manager.expects(:destroy_with_record).never
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
      expects(:max_init_time).returns(20).once # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      expects(:sm_initialized=).with(true).once
      expects(:save).once
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:record_init_time_exceeded).never
    simulation_manager.expects(:restart).never
    simulation_manager.expects(:destroy_with_record).never
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
      expects(:sm_initialized).returns(true).once
    end

    infrastructure = stub_everything

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)
    simulation_manager = SimulationManager.new(record, infrastructure)
    simulation_manager.expects(:resource_status).returns(:running).never

    assert (not simulation_manager.should_initialize_sm?)
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

    sm.monitor
  end

end