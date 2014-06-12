require 'test_helper'

class SimulationManagersControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get show" do
    get :show
    assert_response :success
  end

  test "should get code" do
    get :code
    assert_response :success
  end

  test "should get update" do
    get :update
    assert_response :success
  end

end
