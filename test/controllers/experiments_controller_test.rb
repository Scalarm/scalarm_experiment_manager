require 'test_helper'

class ExperimentsControllerTest < ActionController::TestCase

  # TODO?
  # test "experiment_size" do
  #   #post(:calculate_experiment_size)
  # end

  def setup
    ExperimentsController.any_instance.stubs(:authenticate)
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

end
