require 'test_helper'
require 'db_helper'

class Information::ChartControllerTest < ActionController::TestCase
  include DBHelper

  def test_register_address
    authorize_request(request)
    post :register, address: 'some_address'
    assert_response :success
    assert_equal 'ok', JSON.parse(response.body)['status']

    get :list
    assert_response :success
    assert_includes JSON.parse(response.body), 'some_address'
  end

  def test_register_address_unauthorized
    authorize_request(request)
    get :list
    assert_response :success
    assert_not_includes JSON.parse(response.body), 'some_address'

    clear_authorization(request)
    post :register, address: 'some_address'
    assert_response 401
    authorize_request(request)
  end

  add_test_get_list
  add_test_register_address
  add_test_register_address_unauthorized
  add_test_deregister_address

end
