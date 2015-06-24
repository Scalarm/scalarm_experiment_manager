module ControllerIntegrationTestHelper
  USER_NAME = 'dummy'
  PASSWORD = 'password'

  def authenticate_session!
    @user = ScalarmUser.new({login: USER_NAME})
    @user.password = PASSWORD
    @user.save
    post '/login', username: USER_NAME, password: PASSWORD
  end

  # def accept_json!
  #   Rails.application.config.action_controller.use_accept_header = true
  #   @request.env['HTTP_ACCEPT'] = 'application/json'
  # end
end