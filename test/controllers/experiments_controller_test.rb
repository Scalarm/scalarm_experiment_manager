require 'test_helper'

class ExperimentsControllerTest < ActionController::TestCase

  def setup
    stub_authentication
    ExperimentsController.any_instance.stubs(:load_simulation)
  end

  test 'create should call proper constructor without type' do
    ExperimentsController.any_instance.expects(:create_experiment).returns({})
    post :create
  end

  test 'create should call proper constructor when type is experiment' do
    ExperimentsController.any_instance.expects(:create_experiment).returns({})
    post :create, type: 'experiment'
  end

  test 'create should call proper constructor when type is supervised' do
    ExperimentsController.any_instance.expects(:create_supervised_experiment).returns({})
    post :create, type: 'supervised'
  end

  test 'create should call proper constructor when type is custom_points' do
    ExperimentsController.any_instance.expects(:create_custom_points_experiment).returns({})
    post :create, type: 'custom_points'
  end

  test 'create should raise ValidationError when workers scaling is enabled and its params are missing' do
    # given
    # when
    post :create, format: :json, workers_scaling: 'true'
    # then
    assert_response :precondition_failed
    response_hash = JSON.parse(response.body)
    assert_nothing_raised do
      response_hash.assert_valid_keys('status', 'reason')
    end
    assert_equal 'error', response_hash['status']
  end

  test 'create should initialize workers scaling when workers scaling is enabled parameters are present' do
    # given
    initializer = mock do
      expects(:validate_params)
      expects(:start).with(:experiment)
    end
    WorkersScaling::Initializer.expects(:new).returns(initializer)
    ExperimentsController.any_instance.expects(:create_experiment).returns({status: :ok, experiment: :experiment})
    # when
    post :create, format: :json, workers_scaling: 'true'
    # then
    assert_response :success
  end

  test 'create should return json responce given by experiments constructors' do
    # given
    ExperimentsController.any_instance.expects(:create_experiment).returns({
      status: :ok,
      json: {status: :ok}
    })
    # when
    post :create, format: :json
    # then
    assert_response :success
    response_hash = JSON.parse(response.body)
    assert_nothing_raised do
      response_hash.assert_valid_keys('status')
    end
    assert_equal 'ok', response_hash['status']
  end

  test 'create should return html responce given by experiments constructors' do
    # given
    ExperimentsController.any_instance.expects(:create_experiment).returns({
       status: :ok,
       html: experiments_path
    })
    # when
    post :create
    # then
    assert_redirected_to experiments_path
  end

  test 'create should return json with error when json and html responses from constructor are missing' do
    # given
    ExperimentsController.any_instance.expects(:create_experiment).returns({})
    # when
    post :create, format: :json
    # then
    assert_response :success
    response_hash = JSON.parse(response.body)
    assert_nothing_raised do
      response_hash.assert_valid_keys('status', 'message')
    end
    assert_equal 'error', response_hash['status']
  end

  test 'create should redirect to index with flash error when json and html responses from constructor are missing' do
    # given
    ExperimentsController.any_instance.expects(:create_experiment).returns({})
    # when
    post :create
    # then
    assert_redirected_to experiments_path
    assert flash[:error], 'Error message should be present in flash'
  end

  test 'get index json should return user running non completed experiments id collection' do
    ExperimentsController.any_instance.stubs(:load_historical_experiments).returns([])
    ExperimentsController.any_instance.stubs(:load_simulations).returns([])

    experiment1_id = BSON::ObjectId.new
    experiment2_id = BSON::ObjectId.new

    experiment1 = mock 'experiment1' do
      stubs(:id).returns(experiment1_id)
      stubs(:start_at).returns(Time.now)
      stubs(:completed?).returns(true)
    end

    experiment2 = mock 'experiment2' do
      stubs(:id).returns(experiment2_id)
      stubs(:start_at).returns(Time.now)
      stubs(:completed?).returns(false)
    end

    experiments = [experiment1, experiment2]

    @user.stubs(:get_running_experiments).returns(experiments)

    @request.headers['Accept'] = 'application/json'
    get :index, {}

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal 1, body['running'].count
    assert_equal 1, body['completed'].count
    assert_equal experiment2_id.to_s, body['running'].first.to_s
    assert_equal experiment1_id.to_s, body['completed'].first.to_s

  end

  STATS_PARAMS_CONFIGURATIONS = [
      {
          method_name: :simulations_statistics,
          default_value: true,
          result_keys: [:all, :sent, :done_num, :done_percentage, :generated, :avg_execution_time]
      },
      {
          method_name: :progress_bar,
          default_value: true,
          result_keys: [:progress_bar]
      },
      {
          method_name: :completed,
          default_value: true,
          result_keys: [:completed]
      },
      {
          method_name: :predicted_finish_time,
          default_value: true,
          result_keys: [:predicted_finish_time]
      },
      {
          method_name: :workers_scaling_active,
          default_value: false,
          result_keys: [:workers_scaling_active]
      }
  ]

  def stub_experiment_statistics
    STATS_PARAMS_CONFIGURATIONS.each do |configuration|
      result = configuration[:result_keys].map { |key| [key, "#{key} value"] }.to_h
      ExperimentStatistics.any_instance.stubs(configuration[:method_name]).returns(result)
    end
  end

  def self.create_stats_param_test(method_name, default_value, result_keys)
    default_behaviour = (default_value ? 'present' : 'absent')
    instance_eval do
      test "result of method #{method_name} should be present in returned JSON when param #{method_name} is set to true" do
        # given
        stub_experiment_statistics
        ExperimentsController.any_instance.stubs(:load_experiment)
        # when
        get :stats, id: 'id', method_name => 'true'
        # then
        assert_response :success

        stats = JSON.parse(response.body)

        result_keys.each do |key|
          assert stats.include?(key.to_s), "Key '#{key}' should be present in returned JSON"
        end
      end

      test "result of method #{method_name} should be absent in returned JSON when param #{method_name} is set to false" do
        # given
        stub_experiment_statistics
        ExperimentsController.any_instance.stubs(:load_experiment)
        # when
        get :stats, id: 'id', method_name => 'false'
        # then
        assert_response :success

        stats = JSON.parse(response.body)

        result_keys.each do |key|
          assert (not stats.include?(key.to_s)), "Key '#{key}' should be absent in returned JSON"
        end
      end

      test "result of method #{method_name} should be #{default_behaviour} in returned JSON when param #{method_name} is unset" do
        # given
        stub_experiment_statistics
        ExperimentsController.any_instance.stubs(:load_experiment)
        # when
        get :stats, id: 'id'
        # then
        assert_response :success

        stats = JSON.parse(response.body)

        result_keys.each do |key|
          assert_equal default_value, stats.include?(key.to_s), "Key '#{key}' should be #{default_behaviour} in returned JSON"
        end
      end
    end
  end
  STATS_PARAMS_CONFIGURATIONS.each do |configuration|
    create_stats_param_test(configuration[:method_name], configuration[:default_value], configuration[:result_keys])
  end

  test 'create should call proper constructor when type is from_existing' do
    ExperimentsController.any_instance.expects(:create_experiment_from_existing).returns({})
    post :create, type: 'from_existing'
  end
  
end
