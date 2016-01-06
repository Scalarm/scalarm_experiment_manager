require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentsControllerMethodsTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!

    @experiment = Experiment.new({"is_running"=>true, "user_id"=>@user.id,
      "replication_level"=>1,
      "time_constraint_in_sec"=>3300,
      "scheduling_policy"=>"monte_carlo",
      "name"=>"multi",
      "description"=>"  ",
      "parameters_constraints"=>[],
      "doe_info"=>[],
      "experiment_input"=>[{"entities"=>
        [{"parameters"=>[{"id"=>"parameter1", "label"=>"Param 1",
          "parametrization_type"=>"range", "type"=>"float", "min"=>"0",
          "max"=>"1000", "with_default_value"=>false, "index"=>1,
          "parametrizationType"=>"range", "step"=>"200.0", "in_doe"=>false},
          {"id"=>"parameter2", "label"=>"Param 2", "parametrization_type"=>"range",
            "type"=>"float", "min"=>-100, "max"=>100, "with_default_value"=>false,
            "index"=>2, "parametrizationType"=>"value", "value"=>"-100", "in_doe"=>false}]}]}],
            "labels"=>"parameter1,parameter2", })

    @experiment.save
  end

  def teardown
    super
  end

  test "get_result should return hash with result when simulation run exists" do
    get next_simulation_experiment_path(@experiment.id)
    sim_run = JSON.parse(response.body)
    post mark_as_complete_experiment_simulation_path(@experiment.id, sim_run["simulation_id"]), {result: {x: 1}.to_json}

    get get_result_experiment_path(@experiment.id, format: :json), {point: sim_run["input_parameters"].to_json}
    response_body = JSON.parse(response.body)

    assert_equal "ok", response_body["status"]
    assert_equal 1, response_body["result"]["x"]
  end

  test "get_result should return error messages when no results were found" do
    get next_simulation_experiment_path(@experiment.id)
    sim_run = JSON.parse(response.body)
    post mark_as_complete_experiment_simulation_path(@experiment.id, sim_run["simulation_id"]), {result: {x: 1}.to_json}

    point = sim_run["input_parameters"]
    point["parameter1"] = -10
    get get_result_experiment_path(@experiment.id, format: :json), {point: point.to_json}
    response_body = JSON.parse(response.body)

    assert_equal "error", response_body["status"]
    assert_equal "Point not found", response_body["message"]
  end
end
