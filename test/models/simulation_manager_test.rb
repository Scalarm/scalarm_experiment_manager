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
      :status
  ]

  def test_has_methods
    mock_record = mock do
      stubs(:resource_id).returns('something')
    end

    mock_infrastructure = mock do
      stubs(:short_name).returns('anything')
    end
    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)

    METHOD_NAMES.each do |method_name|
      assert_respond_to simulation_manager, method_name
    end
  end

  def test_monitor_nothing
    mock_record = mock do
      stubs(:resource_id).returns('other-vm')
      expects(:time_limit_exceeded?).returns(false).once
      expects(:destroy).never
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      stubs(:max_init_time).returns(20.minutes)
      expects(:sm_initialized=).never
      expects(:save).never
    end

    mock_infrastructure = mock do
      stubs(:short_name).returns('anything')
      expects(:terminate_simulation_manager).never
      expects(:sm_running?).never
      expects(:initialize_simulation_manager).never
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:sm_terminated?).returns(false).once
    simulation_manager.expects(:should_initialize_sm?).returns(false).once
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor

  end

  def test_delegation
    mock_record = stub_everything('record')
    mock_infrastructure = mock('infrastructure') do
      stubs(:short_name).returns('...')
      SimulationManager::DELEGATES.each do |delegate|
        expects("simulation_manager_#{delegate}").with(mock_record).once
      end
      expects('simulation_manager_wrong').with(mock_record).never
    end
    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

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



end