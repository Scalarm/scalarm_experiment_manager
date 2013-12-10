class SessionsControllerTest < ActionController::TestCase
    tests UserControllerController
    
#     @session_user = nil
#     @current_cookie = nil
    
  def setup
    @config = Rails.application.config
  end

  test 'login get' do
    get :login
    assert_response :success
  end

  test 'redirect to login' do
    get :account
    assert_redirected_to :login
  end

  test 'login access' do
    tmp_login = "tmp_user_#{rand(100)}"
    tmp_password = "pass"

    tmp_user = ScalarmUser.new({"login" => tmp_login})
    tmp_user.password = tmp_password
    tmp_user.save

    post :login, {username: tmp_login, password: tmp_password}

    assert_equal session[:user], tmp_user.id, 'Session user should be the same as tmp user id'

    get :account
    assert_response :success

    tmp_user.destroy
  end

end
