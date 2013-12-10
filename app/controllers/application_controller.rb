class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :exception

  before_filter :authenticate, :except => [:login]

  protected

  def authenticate
    @current_user = nil; @sm_user = false
    
    Rails.logger.debug("Session: #{session[:user]}")

    if session[:user]
      Rails.logger.debug('[authentication] using session data')

      @current_user = ScalarmUser.find_by_id(session[:user])
      authentication_failed if @current_user.blank?

    else
      # if the user provides a valid certificate
      if request.env.include?('HTTP_SSL_CLIENT_S_DN') and request.env['HTTP_SSL_CLIENT_S_DN'] != '(null)' and request.env['HTTP_SSL_CLIENT_VERIFY'] == 'SUCCESS'
        Rails.logger.debug("[authentication] using DN: '#{request.env['HTTP_SSL_CLIENT_S_DN']}'")

        begin
          session[:user] = ScalarmUser.authenticate_with_certificate(request.env['HTTP_SSL_CLIENT_S_DN']).id
          @current_user = ScalarmUser.find_by_id(session[:user])
          flash[:notice] = t('login_success')
        rescue Exception => e
          reset_session
          flash[:error] = e.to_s

          redirect_to :login
        end

      # if the user provides user and password with basic auth -> it can be either user or Simulation manager
      elsif request.env.include?('HTTP_AUTHORIZATION') and request.env['HTTP_AUTHORIZATION'].include?('Basic')

        authenticate_or_request_with_http_basic do |sm_uuid, password|
          temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(sm_uuid)

          unless temp_pass.nil?
            Rails.logger.debug("[authentication] SM using uuid: '#{sm_uuid}'")
            correct = ((not temp_pass.nil?) and (temp_pass.password == password))
            @sm_user = true if correct

            correct
          else
            Rails.logger.debug("[authentication] using login: '#{sm_uuid}'")
            @current_user = ScalarmUser.authenticate_with_password(sm_uuid, password)
          end

        end

      else
        authentication_failed
      end

    end

  end

  def authentication_failed
    reset_session
    flash[:error] = 'You have to login first'

    Rails.logger.debug('[authentication] failed -> redirect')

    session[:intended_action] = action_name
    session[:intended_controller] = controller_name

    redirect_to :login
  end

end
