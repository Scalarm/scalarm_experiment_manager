require 'test_helper'
require 'json'
require 'db_helper'

require 'infrastructure_facades/simulation_manager'

class SimulationManagerIntegrationTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super

    @experiment = Experiment.new({name: 'experiment_mocked'}).save
    @supervised_experiment = SupervisedExperiment.new({name: 'supervised_mocked'}).save
    @supervised_experiment.stubs(:supervised).returns(true)

    @experiment.stubs(:experiment_input).returns({})
    @supervised_experiment.stubs(:experiment_input).returns({})

    @record = DummyRecord.new({})

    # by default, use normal experiment
    # re-stub to change
    @record.stubs(:experiment).returns(@experiment)
    @infrastructure = stub_everything
    @sm = SimulationManager.new(@record, @infrastructure)

    # to detect exceptions rescued by monitoring loop
    @sm.logger.expects(:error).never

    @sm.record.stubs(:time_limit_exceeded?).returns(false)
    @sm.record.stubs(:store_error)
  end

  def teardown
    super
  end

  # Given
  #   all simulation runs of the experiment are running,
  #   and simulation manager that computes a running simulation fails
  # When
  #   simulation manager monitoring loop checks its record
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
  #   there is one simulation run running
  # When
  #   a simulation manager in running state without simulation run assigned is released
  # Then
  #   the simulation manager transmit to a TERMINATING state (stop effect)
  test 'dismiss stopped simulation managers when there is no simulation runs left to do' do
    # Given
    sim_run = @experiment.create_new_simulation(1)
    sim_run.sm_uuid = 'other_sm_uuid'
    sim_run.save

    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:released)

    # Predicted behaviour
    @sm.expects(:store_terminated_error).never
    @sm.expects(:stop).at_least_once

    # When
    @sm.monitor
  end

  # Given
  #   the supervised experiment has no simulations left to do (all done)
  #   there is a SiM without running simulation
  # When
  #   simulation managers monitoring loop is invoked
  # Then
  #   the simulation manager is not stopped
  test 'running sim without any more simulations to run should not be stopped if supervised experiment' do
    # Given
    @record.stubs(:experiment).returns(@supervised_experiment)
    sim_run = @supervised_experiment.create_new_simulation(1)
    sim_run.sm_uuid = 'sim_sm_uuid'
    sim_run.is_done = true
    sim_run.save

    @record.stubs(:sm_uuid).returns('sim_sm_uuid')
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:running_sm)

    # Predicted behaviour
    @sm.expects(:stop).never

    # When
    @sm.monitor
  end

  # Given
  #   all simulation runs of the experiment are done
  #   there is a SiM without running simulation
  # When
  #   simulation managers monitoring loop is invoked
  # Then
  #   the simulation manager is stopped
  test 'running sim without any more simulations to run should be stopped if normal experiment' do
    # Given
    sim_run = @experiment.create_new_simulation(1)
    sim_run.sm_uuid = 'sim_sm_uuid'
    sim_run.is_done = true
    sim_run.save

    @record.stubs(:sm_uuid).returns('sim_sm_uuid')
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:running_sm)

    # Predicted behaviour
    @sm.expects(:stop).at_least_once

    # When
    @sm.monitor
  end

  # Given
  #   the experiment has no simulations left to do (all running)
  #   there is a SiM which is running the simulation run
  # When
  #   simulation managers monitoring loop is invoked
  # Then
  #   the simulation manager should not be stopped
  test 'running sim with running simulation should not be stopped if normal experiment' do
    # Given
    sim_run = @experiment.create_new_simulation(1)
    sim_run.sm_uuid = 'sim_sm_uuid'
    sim_run.to_sent = false
    sim_run.done = false
    sim_run.save

    @record.stubs(:sm_uuid).returns('sim_sm_uuid')
    @sm.stubs(:state).returns(:running)
    @sm.stubs(:resource_status).returns(:running_sm)

    # Predicted behaviour
    @sm.expects(:stop).never

    # When
    @sm.monitor
  end

end
