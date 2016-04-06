require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'csv'

require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentsControllerConfigurationsTest < ActionDispatch::IntegrationTest
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

  # Given:
  #  A custom points experiment created with 10 simulation runs done.
  # When:
  #  Requesting simulation runs with indexes in range [6-10] with /experiments/:id/configurations?min_index=6&max_index=10"
  # Then:
  #  CSV with only these points should be returned
  test 'experiments configurations method should use index_range parameter to generate CSV with given range' do
    min_index = 6
    max_index = 10

    # Given
    scheduled_xs = (1..10).to_a
    sched_csv = "x\n" + scheduled_xs.join("\n")
    post "experiments/#{@experiment.id.to_s}/schedule_multiple_points.json", {csv: sched_csv}
    assert_response :success

    (1..10).each do |index|
      get "experiments/#{@experiment.id.to_s}/next_simulation"
      post "experiments/#{@experiment.id.to_s}/simulations/#{index}/mark_as_complete", {result: {y: index*2}.to_json}
    end

    # When
    get "experiments/#{@experiment.id.to_s}/configurations.json",
        {with_index: '1', min_index: min_index, max_index: max_index}
    content = JSON.parse(response.body)['data']

    # Then
    CSV.parse(content, headers: true) do |row|
      assert_includes min_index..max_index, row['simulation_index'].to_i
    end
  end

  # Given:
  #  A custom points experiment created with 10 simulation runs done.
  # When:
  #  Using /experiments/:id/configurations with min_index and max_index that are not integers
  # Then:
  #  There should be non-success response
  test 'non-success response on non-integer min_index and max_index for configurations' do
    min_index = 'red'
    max_index = 'blue'

    # Given
    scheduled_xs = (1..10).to_a
    sched_csv = "x\n" + scheduled_xs.join("\n")
    post "experiments/#{@experiment.id.to_s}/schedule_multiple_points.json", {csv: sched_csv}
    assert_response :success

    (1..10).each do |index|
      get "experiments/#{@experiment.id.to_s}/next_simulation"
      post "experiments/#{@experiment.id.to_s}/simulations/#{index}/mark_as_complete", {result: {y: index*2}.to_json}
    end

    # When
    get "experiments/#{@experiment.id.to_s}/configurations.json",
        {with_index: '1', min_index: min_index, max_index: max_index}

    # Then
    assert_response :precondition_failed
  end

end
