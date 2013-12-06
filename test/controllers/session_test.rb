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


  #test 'stealing' do
  #
  #
  #
  #  # access to account with stolen session cookie
  #  get :account, {}, { "Cookie" => "#{@config.session_options[:key]}=#{stolen_session}; request_method=GET; "}
  #  assert_response :success, @response.body
  #
  #  puts "Response: " + @response.headers.map{|k,v| "#{k}=#{v}"}.join(', ')
  #  puts "Cookies: " + @response.cookies.map{|k,v| "#{k}=#{v}"}.join(', ')
  #
  #end
  #
  #test 'login post' do
  #  session_user = session[:user] # before posting username/password
  #
  #  post :login, {username: 'jliput', password: 'pass', commit: 'Submit', authenticity_token: 'nrVFlOxe6tMNw9hoWVxLghwUrt0iDF0CPSyhb2yMWmA='} # TODO: try on preloaded user data
  #  puts "Assigns: " + assigns.map{|k,v| "#{k}=#{v}"}.join(', ')
  #  puts "Session: " + session.map{|k,v| "#{k}=#{v}"}.join(', ')
  #  puts "Flash: " + flash.map{|k,v| "#{k}=#{v}"}.join(', ')
  #  puts "Cookies: " + cookies.map{|k,v| "#{k}=#{v}"}.join(', ')
  #
  #  puts "Request cookies: " + @request.cookies.map{|k,v| "#{k}=#{v}"}.join(', ')
  #  puts "Response cookies: " + @response.cookies.map{|k,v| "#{k}=#{v}"}.join(', ')
  #
  #  puts "Response headers: " + @response.headers.map{|k,v| "#{k}=#{v}"}.join(', ')
  #
  #  puts "Session key:" + @config.session_options[:key]
  #
  #  assert_not_equal(session[:user], session_user) # check if session user has been changed
  #
  #  session_user = session[:user] # assign new
  #
  #  get :account
  #  assert_response :success
  #
  #  puts "user: #{session_user} -- #{session[:user]}"
  #
  #  get :account, {}, {"user" => session_user} # try to get to "accounts" page with
  #  #puts "Response: #{@response.body}, #{@response.cookies}"
  #
  #  #get :account, {}, {"user" => '1111'}
  #  #puts "Response: #{@response.body}, #{@response.cookies}"
  #
  #  current_cookie = cookies[@config.session_options[:key]]
  #  puts current_cookie
  #
  #end
  
end
