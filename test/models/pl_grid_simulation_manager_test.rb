require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/pl_grid_simulation_manager'

class PlGridSimulationManagerTest < MiniTest::Test

  def setup
    record = stub_everything do
      stubs(:experiment).returns(stub_everything)
    end
    @sm = PlGridSimulationManager.new(record, stub_everything)
  end

  # PL-Grid Simulation Manager should have all generic monitoring cases except:
  # - try_to_initialize_sm
  def test_have_all_generic_cases
    record = stub_everything 'record'
    infrastructure = stub_everything 'infrastructure'

    plg_sm = PlGridSimulationManager.new(record, infrastructure)
    sm = SimulationManager.new(record, infrastructure)

    assert_empty sm.monitoring_order - plg_sm.monitoring_order
  end

  def test_plgrid_max_time_exceeded?
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:running_sm)
    @sm.stubs(:max_time_exceeded?).returns(true)

    @sm.expects(:restart).once
    @sm.expects(:set_state).with(:initializing).once

    @sm.monitor
  end

  def test_max_time_delegation
    record = stub_everything 'record' do
      expects(:max_time_exceeded?).once
    end

    infrastructure = stub_everything

    sm = PlGridSimulationManager.new(record, infrastructure)

    sm.max_time_exceeded?
  end

end