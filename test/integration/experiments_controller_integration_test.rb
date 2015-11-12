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
    exp = ExperimentFactory.create_custom_points_experiment(@user.id, simulation, name: 'exp')
    exp.save

    get experiments_path, format: :json
    body = response.body
    hash_resp = JSON.parse(body)
    assert_equal 'ok', hash_resp['status'], hash_resp
    assert_equal 1, hash_resp['running'].count, hash_resp
    assert_equal exp.id.to_s, hash_resp['running'][0], hash_resp
  end


  # Given
  #   There is a supervised experiment without any points
  # When
  #   A point is added with /experiments/:id/schedule_point {"point": ...}
  # Then
  #   A simulation run for this point should be generated using /experiments/:id/next_simulation
  test 'next_instance should return scheduled point after schedule_point' do
    # Given
    simulation = Simulation.new({name: 'test_simulation', user_id: @user.id, created_at: Time.now})
    simulation.input_specification = [
        {'entities' => [{'parameters' => [{
                                              'id' => 'x',
                                              'label' => 'X',
                                              'type' => 'integer',
                                              'max' => 100
                                          }]
                        }]}
    ]
    simulation.save

    experiment = ExperimentFactory.create_supervised_experiment(@user.id, simulation)
    experiment.save

    get "/experiments/#{experiment.id.to_s}/next_simulation"
    assert_response :success

    # When
    scheduled_x = 5

    post "experiments/#{experiment.id.to_s}/schedule_point.json", {point: {x: scheduled_x}.to_json}

    # Then
    get "/experiments/#{experiment.id.to_s}/next_simulation"
    assert_response :success
    success_response = JSON.parse(response.body)
    assert_equal 'ok', success_response['status']
    assert success_response.has_key?('input_parameters')
    assert_equal scheduled_x, success_response['input_parameters']['x'].to_i
    puts success_response

    get "/experiments/#{experiment.id.to_s}/next_simulation"
    assert_response :success
    wait_response = JSON.parse(response.body)
    assert_equal 'wait', wait_response['status']
    assert_nil wait_response['input_parameters']
  end


end
