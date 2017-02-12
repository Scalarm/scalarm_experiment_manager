require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'
require 'controller_integration_test_helper'

class SimulationsControllerIntegrationTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!
  end

  def teardown
    super
  end

  test 'simulations GET index should return simulation scenarios id accessible by user' do

    simulation = Simulation.new({
         'name' => 'test',
         'user_id' => @user.id,
         'created_at' => Time.now
     })
    simulation.save

    simulation2 = Simulation.new({
        'name' => 'test2',
        'user_id' => @user.id,
        'created_at' => Time.now
    })
    simulation2.save

    #test json response with valid ids
    get simulation_scenarios_path, format: :json
    body = response.body
    sim_hash = JSON.parse(body)
    assert_equal 2, sim_hash["simulation_scenarios"].count, sim_hash
    assert_includes sim_hash["simulation_scenarios"], simulation.id.to_s


    ## test for hmtl response
    get simulation_scenarios_path
    assert_response 200, response.body
    assert_equal "text/html; charset=utf-8", response["Content-Type"]
  end

  test 'simulations POST host_info should store given information about host executing the simulation run' do
    create_fake_experiment

    host_info = {
        "hostname" => 'example.com', "platform" => 'ubuntu', "platform_family" => 'debian',
        "platform_version" => '14.04', "kernel_version" => '4.0', "virtualization_system" => 'kvm',
        "virtualization_role" => 'host', "cores" => 4, "vendor_id" => 'intel', "family" => 'lake',
        "model" => 'thebest', "stepping" => 6, "model_name" => 'latest', "mhz" => 2.6, "cache_size" => 1024,
        "flags" => ['a', 'b'], "timestamp" => Time.now.to_i
    }

    post host_info_experiment_simulation_path(experiment_id: @experiment.id, id: @simulation_run.index, format: :json),
         host_info: host_info.to_json
    assert_response 200, response.status

    get experiment_simulation_path(experiment_id: @experiment.id, id: @simulation_run.index), format: :json
    assert_response 200, response.status

    sim = JSON.parse(response.body)

    assert_equal host_info, sim['host_info']
  end

  test 'simulations POST performance_stats should register given data as performance statistics inside simulation run' do
    create_fake_experiment

    first_stats = { "timestamp" => Time.now.to_i, "utime" => 1.0, "stime" => 2.0, "iowait" => 3.0, "rss" => 4,
                    "vms" => 5, "swap" => 6, "read_count" => 7, "write_count" => 8, "read_bytes" => 9,
                    "write_bytes" => 10 }

    post performance_stats_experiment_simulation_path(experiment_id: @experiment.id, id: @simulation_run.index,
                                                      format: :json), stats: first_stats.to_json
    assert_response 200, response.status

    get experiment_simulation_path(experiment_id: @experiment.id, id: @simulation_run.index), format: :json
    assert_response 200, response.status

    sim = JSON.parse(response.body)
    perf_stats = sim['performance_stats']

    assert_equal 1, perf_stats.size
    assert_equal first_stats, perf_stats.first

    second_stats = { "timestamp" => Time.now.to_i, "utime" => 11.0, "stime" => 12.0, "iowait" => 13.0, "rss" => 14,
                    "vms" => 15, "swap" => 16, "read_count" => 17, "write_count" => 18, "read_bytes" => 19,
                    "write_bytes" => 20 }

    post performance_stats_experiment_simulation_path(experiment_id: @experiment.id, id: @simulation_run.index,
                                                      format: :json), stats: second_stats.to_json
    assert_response 200, response.status

    get experiment_simulation_path(experiment_id: @experiment.id, id: @simulation_run.index), format: :json
    assert_response 200, response.status

    sim = JSON.parse(response.body)
    perf_stats = sim['performance_stats']

    assert_equal 2, perf_stats.size
    assert_equal second_stats, perf_stats.last
  end

  private

  def create_fake_experiment
    @experiment = Experiment.new(user_id: @user.id, experiment_input:
        [{"id" => "", "label" => "", "entities" =>
            [{"id" => "", "label" => "", "parameters" =>
                [{"id" => "parameter1", "type" => "integer", "label" => "Param1",
                  "min" => "1", "max" => "3", "step" => "1",
                  "with_default_value" => false, "index" => 1,
                  "parametrizationType" => "range", "in_doe" => false}]
             }]
         }], doe_info: [ ])
    @experiment.save

    @simulation_run = @experiment.simulation_runs.new({index: 1, is_done: false, to_sent: false})
    @simulation_run.save
  end

end
