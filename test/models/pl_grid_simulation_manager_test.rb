require 'test/unit'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/pl_grid_simulation_manager'

class PlGridSimulationManagerTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_monitor_nothing
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-job')
      expects(:time_limit_exceeded?).returns(false).once
      expects(:destroy).never
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      stubs(:max_init_time).returns(20.minutes)
      expects(:sm_initialized=).never
      expects(:max_time_exceeded?).returns(false).once
      expects(:save).never
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = PlGridSimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:sm_terminated?).returns(false).once
    simulation_manager.expects(:should_initialize_sm?).returns(false).once
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:install).never
    simulation_manager.expects(:restart).never
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end

  def test_max_time_exceeded?
    mock_record = stub_everything 'record' do
      stubs(:resource_id).returns('other-job')
      expects(:max_init_time).returns(20).once # used for logger message
      expects(:time_limit_exceeded?).returns(false).once
      expects(:experiment_end?).returns(false).once
      expects(:init_time_exceeded?).returns(false).once
      expects(:sm_initialized=).never
      expects(:max_time_exceeded?).returns(true).once
      expects(:save).never
    end

    mock_infrastructure = mock 'infrastructure' do
      stubs(:short_name).returns('anything')
    end

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    simulation_manager = PlGridSimulationManager.new(mock_record, mock_infrastructure)
    simulation_manager.expects(:before_monitor).once
    simulation_manager.expects(:stop_and_destroy).never
    simulation_manager.expects(:sm_terminated?).returns(false).once
    simulation_manager.expects(:should_initialize_sm?).returns(false).once
    simulation_manager.expects(:record_sm_failed).never
    simulation_manager.expects(:install).never
    simulation_manager.expects(:restart).once
    simulation_manager.expects(:after_monitor).once

    # EXECUTION
    simulation_manager.monitor
  end


end