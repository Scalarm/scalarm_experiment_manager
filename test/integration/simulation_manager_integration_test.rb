require 'test_helper'
require 'json'
require 'db_helper'

require 'infrastructure_facades/simulation_manager'

class SimRecordInfrastructureTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super

    @experiment = stub_everything
    @record = stub_everything do
      stubs(:experiment).returns(@experiment)
    end
    @sm = SimulationManager.new(@record, stub_everything)
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
    @experiment = Experiment.new({name: 'experiment_mocked'}).save
    @experiment.stubs(:experiment_input).returns({})

    running_sm_uuid = 'running_sm_uuid'

    sim_run = @experiment.create_new_simulation(1)
    @experiment.create_new_simulation(2).save.rollback!

    sim_run.sm_uuid = running_sm_uuid
    sim_run.save
    puts "Sim: #{@experiment.simulation_runs.where(index: 1).first}"
    puts @experiment.has_simulations_to_run?

    @record.sm_uuid = running_sm_uuid
    @sm.stubs(:state).returns(:running_sm)
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

  end

end
