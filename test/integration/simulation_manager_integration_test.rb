require 'test_helper'
require 'json'
require 'db_helper'

require 'infrastructure_facades/simulation_manager'

class SimRecordInfrastructureTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super

    @experiment = Experiment.new({name: 'experiment_mocked'}).save
    @experiment.stubs(:experiment_input).returns({})
    @record = stub_everything
    @record.stubs(:experiment).returns(@experiment)
    @infrastructure = stub_everything
    @sm = SimulationManager.new(@record, @infrastructure)
  end

  def teardown
    super
  end

  # Given
  #   the experiment has no simulations left to do (all running or done),
  #   and simulation manager that computes a running simulation fails
  # When
  #   and simulation manager monitoring loop checks its record
  # Then
  #   store_terminated_error should be launched
  test 'handling last failed simulation run with terminated_untimely' do
    # Given
    running_sm_uuid = 'running_sm_uuid'

    sim_run = @experiment.create_new_simulation(1)
    sim_run.sm_uuid = running_sm_uuid
    sim_run.save

    @record.stubs(:sm_uuid).returns(running_sm_uuid)
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:released)

    # Predicted behaviour
    @sm.expects(:store_terminated_error).at_least_once

    # When
    @sm.monitor

  end

  # Given
  #   the experiment has no simulations left to do (all running or done)
  # When
  #   a simulation manager in running state whose simulation run is done is dead
  # Then
  #   the simulation manager transmit to a TERMINATING state (stop effect)
  test 'dismiss stopped simulation managers when there is no simulation runs left to do' do
    # Given
    sim_run = @experiment.create_new_simulation(1)
    sim_run.sm_uuid = 'other_sm_uuid'
    sim_run.save
    puts "Sim: #{@sm.no_pending_tasks?}"

    @record.stubs(:sm_uuid).returns('sim_sm_uuid')
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:released)

    # Predicted behaviour
    @sm.expects(:store_terminated_error).never
    @sm.expects(:stop).at_least_once

    # When
    @sm.monitor

  end

end
