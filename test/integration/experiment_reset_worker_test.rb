require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'sidekiq/testing'
require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentResetWorkerTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    Sidekiq::Testing.fake!
    authenticate_session!

    @simulation = Simulation.new({name: 'test_simulation', user_id: @user.id, created_at: Time.now})
    @simulation.input_specification = [{"entities"=>[{"parameters"=>[{"id"=>"parameter1", "label"=>"Param 1", "type"=>"float", "min"=>"0","max"=>"1000"}]}]}]

    @simulation.save

    @experiment_params = {"is_running" => true, "user_id" => @user.id,
                          "start_at" => Time.now,
                          "replication_level" => 1,
                          "time_constraint_in_sec" => 3300,
                          "scheduling_policy" => "monte_carlo",
                          "name" => "multi",
                          "description" => "",
                          "parameters_constraints" => [],
                          "doe_info" => [],
                          "experiment_input" => [{"entities" =>
                                                      [{"parameters" => [{"id" => "parameter1", "label" => "Param 1",
                                                                          "parametrization_type" => "range", "type" => "float", "min" => "0",
                                                                          "max" => "1000", "with_default_value" => false, "index" => 1,
                                                                          "parametrizationType" => "range", "step" => "200.0", "in_doe" => false}]}]}],
                          "labels" => "parameter1,parameter2", "simulation_id" => @simulation.id}

    @experiment = Experiment.new(@experiment_params)

    @experiment.save

    @experiment.simulation_runs.new({is_done: true, result: { "error_param1" => 1, "error_param2" => 2 }, is_error: true}).save
    @experiment.simulation_runs.new({is_done: true, result: { "param1" => 1, "param2" => 2 }}).save
  end

  def teardown
    super
  end

  test 'experiment reset worker should remove all simulation runs from the experiment but the experiment is should be the same' do
    size = @experiment.experiment_size

    worker = ExperimentResetWorker.new
    worker.perform(@experiment.id.to_s)

    experiment = Experiment.where(id: @experiment.id).first
    assert_equal 0, experiment.simulation_runs.count
    assert_equal size, experiment.size
  end

end
