require 'test_helper'

class ExperimentsControllerTest < ActionController::TestCase

  def setup
    stub_authentication
    ExperimentsController.any_instance.stubs(:load_simulation)
  end

  test 'create should call proper constructor without type' do
    ExperimentsController.any_instance.expects(:create_experiment)
    assert_raises ActionView::MissingTemplate do
      post :create
    end
  end

  test 'create should call proper constructor when type is experiment' do
    ExperimentsController.any_instance.expects(:create_experiment)
    assert_raises ActionView::MissingTemplate do
      post :create, type: 'experiment'
    end
  end

  test 'create should call proper constructor when type is supervised' do
    ExperimentsController.any_instance.expects(:create_supervised_experiment)
    assert_raises ActionView::MissingTemplate do
      post :create, type: 'supervised'
    end
  end

  test 'create should call proper constructor when type is custom_points' do
    ExperimentsController.any_instance.expects(:create_custom_points_experiment)
    assert_raises ActionView::MissingTemplate do
      post :create, type: 'custom_points'
    end
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
    ExperimentsController.any_instance.stubs(:transform_experiment)
        .with(experiment1).returns(experiment1)
    ExperimentsController.any_instance.stubs(:transform_experiment)
        .with(experiment2).returns(experiment2)

    @request.headers['Accept'] = 'application/json'
    get :index, {}

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal 1, body['running'].count
    assert_equal 1, body['completed'].count
    assert_equal experiment2_id.to_s, body['running'].first.to_s
    assert_equal experiment1_id.to_s, body['completed'].first.to_s

  end

end
