require 'test_helper'
require 'db_helper'

class UserControllerControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super
  end

  def teardown
    super
  end

  def test_login_get
    get :login
    assert_response :success
  end

  def test_redirect_to_login
    get :account
    assert_redirected_to :login
  end

  def test_login_access
    tmp_user = set_account

    get :account
    assert_response :success

    tmp_user.destroy
  end

  def test_account_page_contains_information_about_password_change
    tmp_user = set_account

    get :account
    assert_response :success

    assert_select '.panel.password-change-msg', I18n.t('user_controller.password_panel.password_change_message')

    tmp_user.destroy
  end

  private

  def set_account
    tmp_login = "tmp_user_#{rand(100)}"
    tmp_password = "pass"

    tmp_user = ScalarmUser.new(login: tmp_login)
    tmp_user.password = tmp_password
    tmp_user.save

    post :login, {username: tmp_login, password: tmp_password}

    assert_equal session[:user], tmp_user.id.to_s, 'Session user should be the same as tmp user id'

    tmp_user
  end

end
