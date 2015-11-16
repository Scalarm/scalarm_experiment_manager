require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentsControllerSchedulePointsTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def create_sample_simulation
    @simulation = Simulation.new({name: 'test_simulation', user_id: @user.id, created_at: Time.now})
    @simulation.input_specification = [
        {'entities' => [{'parameters' => [{
                                              'id' => 'x',
                                              'label' => 'X',
                                              'type' => 'integer',
                                              'max' => 100
                                          }]
                        }]}
    ]
    @simulation.save
  end

  def create_sample_supervised_experiment
    @experiment = ExperimentFactory.create_supervised_experiment(@user.id, @simulation)
    @experiment.save
  end

  def setup
    super
    authenticate_session!

    create_sample_simulation
    create_sample_supervised_experiment
  end

  def teardown
    super
  end

  # Given
  #   There is a supervised experiment without any points
  # When
  #   A point is added with /experiments/:id/schedule_point {"point": ...}
  # Then
  #   A simulation run for this point should be generated using /experiments/:id/next_simulation
  test 'next_instance should return scheduled point after schedule_point' do
    # Given
    get "/experiments/#{@experiment.id.to_s}/next_simulation"
    assert_response :success

    # When
    scheduled_x = 5

    post "experiments/#{@experiment.id.to_s}/schedule_point.json", {point: {x: scheduled_x}.to_json}

    # Then
    get "/experiments/#{@experiment.id.to_s}/next_simulation"
    assert_response :success
    success_response = JSON.parse(response.body)
    assert_equal 'ok', success_response['status']
    assert success_response.has_key?('input_parameters')
    assert_equal scheduled_x, success_response['input_parameters']['x'].to_i

    get "/experiments/#{@experiment.id.to_s}/next_simulation"
    assert_response :success
    wait_response = JSON.parse(response.body)
    assert_equal 'wait', wait_response['status']
    assert_nil wait_response['input_parameters']
  end

  # G:
  #   There is a supervised experiment without any points
  # W:
  #   A multiple points are added with /experiments/:id/schedule_multiple_points {"csv": ...}
  # T:
  #   A multiple simulation runs for these point should be generated using /experiments/:id/next_simulation
  test 'next_instance should return multiple scheduled points after schedule_multiple_points' do
    # Given
    get "/experiments/#{@experiment.id.to_s}/next_simulation"
    assert_response :success

    # When
    scheduled_xs = (1..10).to_a

    sched_csv = "x\n" + scheduled_xs.join("\n")

    post "experiments/#{@experiment.id.to_s}/schedule_multiple_points.json", {csv: sched_csv}
    assert_response :success


    # Then
    scheduled_xs.each do |x|
      get "/experiments/#{@experiment.id.to_s}/next_simulation"
      assert_response :success
      success_response = JSON.parse(response.body)
      assert_equal 'ok', success_response['status'], "Non-OK next_simulation response for x=#{x} point"
      assert success_response.has_key?('input_parameters')
      assert_equal x, success_response['input_parameters']['x'].to_i
    end

    # After all next_simulations
    get "/experiments/#{@experiment.id.to_s}/next_simulation"
    assert_response :success
    wait_response = JSON.parse(response.body)
    assert_equal 'wait', wait_response['status']
    assert_nil wait_response['input_parameters']
  end

end
