require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentsControllerIntegrationTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!

    @simulation = Simulation.new({name: 'test_simulation', user_id: @user.id, created_at: Time.now})
    @simulation.input_specification = [{"entities"=>
                [{"parameters"=>[{"id"=>"parameter1", "label"=>"Param 1",
                  "type"=>"float", "min"=>"0","max"=>"1000"},
                  {"id"=>"parameter2", "label"=>"Param 2",
                    "type"=>"float", "min"=>-100, "max"=>100}]}]}]

    @simulation.save

    @experiment_params = {"is_running"=>true, "user_id"=>@user.id,
                          "start_at" => Time.now,
          "replication_level"=>1,
          "time_constraint_in_sec"=>3300,
          "scheduling_policy"=>"monte_carlo",
          "name"=>"multi",
          "description"=>"",
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
                "labels"=>"parameter1,parameter2", "simulation_id" => @simulation.id}

    @experiment = Experiment.new(@experiment_params)
    @experiment.save
  end

  def teardown
    super
  end

  test 'one custom experiment on list' do
    simulation = stub_everything 'simulation' do
      stubs(:input_specification).
          returns([
                      {'entities' => [{'parameters' => []}]}
                  ])
      stubs(:input_parameters).returns({})
    end

    experiment_count = Experiment.all.count
    exp = ExperimentFactory.create_custom_points_experiment(@user.id, simulation, name: 'exp')
    exp.save

    get experiments_path, format: :json
    assert_response :success

    body = response.body
    hash_resp = JSON.parse(body)
    assert_equal 'ok', hash_resp['status'], hash_resp
    assert_equal experiment_count + 1, hash_resp['running'].count, hash_resp
    assert  hash_resp['running'].include?(exp.id.to_s)
  end

  test 'create with from_existing type should return a new experiment with the same parametrization as the given one' do
    # given
    @experiment.simulation_runs.new({is_done: true, result: { "error_param1" => 1, "error_param2" => 2 }, is_error: true}).save
    @experiment.simulation_runs.new({is_done: true, result: { "param1" => 1, "param2" => 2 }}).save

    # when
    post experiments_path, type: 'from_existing', experiment_id: @experiment.id.to_s, experiment_name: 'name', experiment_description: 'desc',
         simulation_id: @simulation.id.to_s

    # then
    follow_redirect!
    assert_equal 200, status

    experiment = Experiment.where(name: 'name').first

    assert_not_nil experiment
    assert_equal @experiment.experiment_size, experiment.experiment_size
    assert_equal @experiment_params['experiment_input'], experiment.experiment_input
    assert_equal 0, experiment.simulation_runs.count
  end

end
