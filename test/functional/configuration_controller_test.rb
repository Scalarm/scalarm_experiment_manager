require 'test_helper'

class ConfigurationControllerTest < ActionController::TestCase
  test "should get managers" do
    get :managers
    assert_response :success
  end

end
