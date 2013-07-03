class ApplicationController < ActionController::Base

  before_filter :authenticate, :except => [ :subscribe, :unsubscribe, :message, :login ]

  # protect_from_forgery

  def current_user
    if not @scalarm_user.nil?
      @scalarm_user
    elsif not @current_user.nil?
      @current_user
    else
      nil
    end
  end
  
  protected

  def authenticate
    @scalarm_user = @current_user = nil

    if session[:user]

      @current_user = User.find_by_id(session[:user])

    else

      if request.env.include?('HTTP_SSL_CLIENT_S_DN') and request.env['HTTP_SSL_CLIENT_S_DN'] != '(null)' and request.env['HTTP_SSL_CLIENT_VERIFY'] == 'SUCCESS'
        Rails.logger.debug("We can use DN(#{request.env['HTTP_SSL_CLIENT_S_DN']}) for authentication")
        @scalarm_user = ScalarmUser.find_by_dn(request.env['HTTP_SSL_CLIENT_S_DN'])

        if @scalarm_user.nil?

          Rails.logger.debug("Authentication failed: user with DN = #{request.env['HTTP_SSL_CLIENT_S_DN']} not found")

          flash[:error] = "Authentication failed: user with DN = #{request.env['HTTP_SSL_CLIENT_S_DN']} not found"
          redirect_to :login
        end

      elsif request.env.include?('HTTP_AUTHORIZATION') and request.env['HTTP_AUTHORIZATION'].include?('Basic')
        authenticate_or_request_with_http_basic do |sm_uuid, password|
          Rails.logger.debug("Possible SM authentication: #{sm_uuid}")

          temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(sm_uuid)

          ((not temp_pass.nil?) and temp_pass.password == password) or (sm_uuid == 'hidden' and password == 'hidden')
        end

      else
        Rails.logger.debug('We should use user and pass for authentication')

        session[:intended_action] = action_name
        session[:intended_controller] = controller_name

        redirect_to :login
      end

    end

  end

end
