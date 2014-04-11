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
    mock_record = Object
    mock_infrastructure = Object
    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)

    METHOD_NAMES.each do |method_name|
      assert_respond_to simulation_manager, method_name
    end
  end

  def test_experiment_end?
    mock_record = Object
    #mock_record.stubs()

    mock_infrastructure = Object

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)
  end

  def test_monitor
    mock_record = Object
    mock_infrastructure = Object

    simulation_manager = SimulationManager.new(mock_record, mock_infrastructure)

    mock_record.expects(:time_limit_exceeded?).returns(false).once
    mock_infrastructure.expects(:terminate_task).never
    simulation_manager.expects(:destroy_record).never

    mock_record.expects(:init_time_exceeded?).returns(false).once
    simulation_manager.expects(:status).returns(:running).at_least_once

    mock_record.expects(:experiment_end?).returns(false).once

    simulation_manager.expects(:sm_terminated?).returns(false).once
    simulation_manager.expects(:mark_sm_failed).never

    simulation_manager.expects(:ready_to_initialize_sm?).returns(false).once


  end
end