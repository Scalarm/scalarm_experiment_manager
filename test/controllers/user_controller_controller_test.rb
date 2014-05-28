require 'test_helper'

class UserControllerControllerTest < ActionController::TestCase
  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
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
