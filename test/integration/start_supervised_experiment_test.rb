require 'test_helper'
require 'json'
require 'db_helper'
require 'supervised_experiment_helper'

class StartSupervisedExperimentTest < ActionDispatch::IntegrationTest
  include SupervisedExperimentHelper

  # test entire process of creating supervised experiment
  test "successful start of supervised experiment with json result" do
    # mocks
    # mock supervised experiment instance to return specified id (needed to test post params to supervisor)
    supervised_experiment = ExperimentFactory.create_supervised_experiment(@user.id, @simulation)
    supervised_experiment.expects(:id).returns(BSON::ObjectId(EXPERIMENT_ID)).times(3)
    ExperimentFactory.expects(:create_supervised_experiment).returns(supervised_experiment)

    # set user and password to specified value (needed to test post params to supervisor)
    SecureRandom.expects(:uuid).returns(USER_NAME).at_least_once
    password = mock {expects(:password).returns(PASSWORD)}
    SimulationManagerTempPassword.expects(:create_new_password_for).with(USER_NAME, BSON::ObjectId(EXPERIMENT_ID))
        .returns(password)

    # mock experiment supervisor response with testing proper query params
    RestClient.expects(:post).with do |url, params|
      url == EXPERIMENT_SUPERVISOR_ADDRESS and
      params[:supervisor_id] == SCRIPT_ID and
      JSON.parse(params[:config]) == FULL_SCRIPT_PARAMS
    end.returns(RESPONSE_ON_SUCCESS.to_json)
    # test
    assert_difference 'Experiment.count', 1 do
      post "#{experiments_path}.json", simulation_id: @simulation.id,
             supervisor_script_id: SCRIPT_ID,
             supervisor_script_params: INPUT_SCRIPT_PARAMS.to_json,
             type: 'supervised'
    end
    response_hash = JSON.parse(response.body)
    # test if response contains only allowed entries with proper values
    assert_nothing_raised do
      response_hash.assert_valid_keys('status', 'experiment_id', 'pid')
    end
    assert_equal response_hash['status'], 'ok'
    assert_equal response_hash['pid'], PID
    assert_equal response_hash['experiment_id'], EXPERIMENT_ID.to_s
  end

  # test only redirection part of creating supervised experiment
  test "test proper redirection on successful start of supervised experiment" do
    # mocks
    # mock experiment supervisor response
    RestClient.expects(:post).returns(RESPONSE_ON_SUCCESS.to_json)
    #test
    assert_difference 'Experiment.count', 1 do
      post experiments_path, simulation_id: @simulation.id,
           supervisor_script_id: SCRIPT_ID,
           supervisor_script_params: INPUT_SCRIPT_PARAMS.to_json,
           type: 'supervised'
    end
    assert_equal Experiment.count, 1 # to make sure proper id in next line
    assert_redirected_to experiment_path(Experiment.first.id)
    assert flash['error'].nil?, 'Flash[\'error\'] is not empty'
    follow_redirect!
    assert_template 'experiments/_experiment_result'
  end

  test "test proper behavior on failure to start supervisor script with json response" do
    # mocks
    # mock experiment supervisor response
    RestClient.expects(:post).returns(RESPONSE_ON_FAILURE.to_json)
    # test
    assert_no_difference 'Experiment.count' do
      post "#{experiments_path}.json", simulation_id: @simulation.id,
           supervisor_script_id: SCRIPT_ID,
           supervisor_script_params: INPUT_SCRIPT_PARAMS.to_json,
           type: 'supervised'
    end
    response_hash = JSON.parse(response.body)
    # test if response contains only allowed entries with proper values
    assert_nothing_raised do
      response_hash.assert_valid_keys('status', 'reason')
    end
    assert_equal response_hash['status'], 'error'
    assert_equal response_hash['reason'], REASON
  end

  test "test proper behavior on failure to connect with experiment supervisor with json response" do
    # mocks
    # mock experiment supervisor response
    RestClient.expects(:post).raises(StandardError, REASON)
    # test
    assert_no_difference 'Experiment.count' do
      post "#{experiments_path}.json", simulation_id: @simulation.id,
           supervisor_script_id: SCRIPT_ID,
           supervisor_script_params: INPUT_SCRIPT_PARAMS.to_json,
           type: 'supervised'
    end
    response_hash = JSON.parse(response.body)
    # test if response contains only allowed entries with proper values
    assert_nothing_raised do
      response_hash.assert_valid_keys('status', 'reason')
    end
    assert_equal response_hash['status'], 'error'
    assert_equal response_hash['reason'], REASON
  end

  # test only redirection part of creating supervised experiment
  test "test proper redirection on unsuccessful start of supervised experiment" do
    # mocks
    # mock experiment supervisor response
    RestClient.expects(:post).returns(RESPONSE_ON_FAILURE.to_json)
    # test
    assert_no_difference 'Experiment.count', 1 do
      post experiments_path, simulation_id: @simulation.id,
           supervisor_script_id: SCRIPT_ID,
           supervisor_script_params: INPUT_SCRIPT_PARAMS.to_json,
           type: 'supervised'
    end
    assert_redirected_to experiments_path
    assert_not flash['error'].nil?, 'Flash[\'error\'] is empty'
  end


  test "successful start of supervised experiment without starting supervisor script" do
    # mocks
    # mock supervised experiment instance to return specified id (needed to test post params to supervisor)
    supervised_experiment = ExperimentFactory.create_supervised_experiment(@user.id, @simulation)
    supervised_experiment.expects(:id).returns(BSON::ObjectId(EXPERIMENT_ID))
    ExperimentFactory.expects(:create_supervised_experiment).returns(supervised_experiment)
    # mock experiment supervisor response with testing proper query params
    RestClient.expects(:post).never
    # test
    assert_difference 'Experiment.count', 1 do
      post "#{experiments_path}.json", simulation_id: @simulation.id, type: 'supervised'
    end
    response_hash = JSON.parse(response.body)
    # test if response contains only allowed entries with proper values
    assert_nothing_raised do
      response_hash.assert_valid_keys('status', 'experiment_id')
    end
    assert_equal response_hash['status'], 'ok'
    assert_equal response_hash['experiment_id'], EXPERIMENT_ID.to_s
  end
end
