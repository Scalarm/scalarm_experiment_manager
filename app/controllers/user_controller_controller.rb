require 'openid'
require 'openid/extensions/ax'

require 'openid_providers/google_openid'

class UserControllerController < ApplicationController
  include UserControllerHelper
  include GoogleOpenID

  def successful_login
    unless session.has_key?(:intended_action) and session.has_key?(:intended_controller)
      session[:intended_controller] = :experiments
      session[:intended_action] = :index
    end

    flash[:notice] = t('login_success')
    Rails.logger.debug('[authentication] successful')

    redirect_to url_for :controller => session[:intended_controller], :action => session[:intended_action]
  end

  def login
    Rails.logger.debug("Flash #{flash[:error]}")
    if request.post?
      begin
        session[:user] = ScalarmUser.authenticate_with_password(params[:username], params[:password]).id
        #session[:grid_credentials] = GridCredentials.find_by_user_id(session[:user])

        successful_login
      rescue Exception => e
        Rails.logger.debug("Exception: #{e}")
        reset_session
        flash[:error] = e.to_s

        redirect_to login_path
      end
    end
  end

  def logout
    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
      infrastructure_info[:facade].clean_tmp_credentials(@current_user.id, session)
    end

    reset_session
    flash[:notice] = t('logout_success')

    redirect_to login_path
  end

  def change_password
    if params[:password] != params[:password_repeat]
      flash[:error] = t('password_repeat_error')
    else
      @current_user.password = params[:password]
      @current_user.save

      flash[:notice] = t('password_changed')
    end

    redirect_to :action => 'account'
  end

  # --- OpenID support ---

  private

  # Get stateless mode OpenID::Consumer instance for this controller.
  def consumer
    if @consumer.nil?
      @consumer = OpenID::Consumer.new(session, nil) # 'nil' for stateless mode
    end
    return @consumer
  end

end
