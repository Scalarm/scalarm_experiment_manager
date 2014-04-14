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

  def test_monitor
    mock_record = Object
    mock_record.stubs(:resource_id).returns('other-vm')
    mock_infrastructure = Object
    mock_infrastructure.stubs(:short_name).returns('anything')
    mock_task_logger = mock
    mock_task_logger.stub_everything
    InfrastructureTaskLogger.stubs(:new).returns(mock_task_logger)

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)

    mock_record.expects(:time_limit_exceeded?).returns(false).once
    mock_infrastructure.expects(:terminate_simulation_manager).never
    mock_record.expects(:destroy).never

    mock_record.expects(:experiment_end?).returns(false).once

    mock_record.expects(:init_time_exceeded?).returns(false).once
    mock_record.stubs(:max_init_time).returns(20.minutes)

    simulation_manager.expects(:sm_terminated?).returns(false).once
    mock_infrastructure.expects(:sm_running?).never
    simulation_manager.expects(:record_sm_failed).never

    simulation_manager.expects(:should_initialize_sm?).returns(false).once
    mock_infrastructure.expects(:initialize_simulation_manager).never
    mock_record.expects(:sm_initialized=).never
    mock_record.expects(:save).never

    # EXECUTION
    simulation_manager.monitor

  end

end