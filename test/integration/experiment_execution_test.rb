require 'test_helper'
require 'mocha'
require 'minitest/autorun'
require 'db_helper'
require 'controller_integration_test_helper'
require 'concurrent'


class ExperimentExecutionTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!

    @simulation = Simulation.new({name: 'test_simulation', user_id: @user.id, created_at: Time.now})
    @simulation.input_specification = [{"entities"=>[{"parameters"=>[{"id"=>"param", "label"=>"1", "type"=>"integer", "min"=>"0","max"=>"1000"}]}]}]
    @simulation.save

    @experiment_size = 100

    @params = {
        'type' => 'experiment',
        'experiment_name' => 'test',
        'experiment_description' => 'test desc',
        'experiment_input' => [{"entities" =>
                                    [{"parameters" =>
                                          [{"id" => "param", "min" => 1, "max" => @experiment_size, "step" => 1,
                                            "parametrizationType" => "range", "type" => "integer"}]
                                     }]
                               }],
        'replication_level' => 1,
        'execution_time_constraint' => 600,
        'parameters_constraints' => {},
        'simulation_id' => @simulation.id,
        'format' => 'json',
        'doe' => "[]"
    }
  end

  def teardown
    super
  end

  test 'user creates an experiment and executes' do
    # experiment submission
    experiment_id = create_experiment(@params, @experiment_size)

    # experiment execution
    i = 0
    while true do
      get next_simulation_experiment_path(experiment_id), format: :json
      assert_response :success

      i += 1 if JSON.parse(response.body)["status"] == "all_sent"

      break if i > 10
    end

    get experiment_stats_experiment_path(experiment_id), format: :json
    assert_response :success

    experiment_stats = JSON.parse(response.body)
    assert_equal @experiment_size, experiment_stats['all']
    assert_equal @experiment_size, experiment_stats['generated']
    assert_equal @experiment_size, experiment_stats['sent']

    # sending results
    1.upto(@experiment_size) do |i|
      post mark_as_complete_experiment_simulation_path(experiment_id, i), result: { x: i }, format: :json
      assert_response :success
    end

    check_experiment_size(experiment_id, @experiment_size, @experiment_size)
  end

  test 'user creates an experiment and executes while some simulations are rolledback' do
    # experiment submission
    experiment_id = create_experiment(@params, @experiment_size)

    # experiment execution
    i = 0
    while true do
      get next_simulation_experiment_path(experiment_id), format: :json
      assert_response :success

      if JSON.parse(response.body)["status"] == "all_sent"
        i += 1
        break if i > 10
      else
        simulation_id = JSON.parse(response.body)["simulation_id"]
        post mark_as_complete_experiment_simulation_path(experiment_id, simulation_id), result: { x: simulation_id }, format: :json
        assert_response :success
      end
    end

    check_experiment_size(experiment_id, @experiment_size, @experiment_size)

    [1, 5, 15, 77, 96].each do |sim_idx|
      Experiment.where(id: experiment_id).first.simulation_runs.where(index: sim_idx).first.rollback!
    end

    get experiment_stats_experiment_path(experiment_id), format: :json
    assert_response :success

    check_experiment_size(experiment_id, @experiment_size, @experiment_size - 5)

    # redo rollbacked simulation runs
    i = 0
    while true do
      get next_simulation_experiment_path(experiment_id), format: :json
      assert_response :success

      if JSON.parse(response.body)["status"] == "all_sent"
        i += 1
        break if i > 10
      else
        simulation_id = JSON.parse(response.body)["simulation_id"]
        post mark_as_complete_experiment_simulation_path(experiment_id, simulation_id), result: { x: simulation_id }, format: :json
        assert_response :success
      end
    end

    check_experiment_size(experiment_id, @experiment_size, @experiment_size)
  end

  def check_experiment_size(experiment_id, expected_size, expected_runs)
    get experiment_stats_experiment_path(experiment_id), format: :json
    assert_response :success

    experiment_stats = JSON.parse(response.body)
    assert_equal expected_size, experiment_stats['all']
    assert_equal expected_runs, experiment_stats['generated']
    assert_equal expected_runs, experiment_stats['done_num']

    exp = Experiment.where(id: experiment_id).first
    assert_equal expected_size, exp.size
    assert_equal expected_runs, exp.simulation_runs.count
    assert_equal expected_runs, exp.simulation_runs.where(is_done: true).count
  end

  def create_experiment(params, expected_size)
    post experiments_path, params
    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal "ok", response_body["status"]

    assert response_body.include?("experiment_id")
    experiment_id = response_body["experiment_id"]

    get experiment_path(experiment_id), format: :json
    assert_response :success

    get experiment_stats_experiment_path(experiment_id), format: :json
    assert_response :success

    experiment_stats = JSON.parse(response.body)
    assert_equal expected_size, experiment_stats['all']

    experiment_id
  end

end
