require 'openid'
require 'openid/extensions/ax'

require 'openid_providers/google_openid'
require 'openid_providers/plgrid_openid'

require 'utils'

class UserControllerController < ApplicationController
  include UserControllerHelper
  include GoogleOpenID
  include PlGridOpenID

  def successful_login
    #unless session.has_key?(:intended_action) and session.has_key?(:intended_controller)
    session[:intended_controller] = :experiments
    session[:intended_action] = :index
    #end

    flash[:notice] = t('login_success')
    Rails.logger.debug('[authentication] successful')

    @user_session = UserSession.create_and_update_session(session[:user].to_s)

    #redirect_to url_for :controller => session[:intended_controller], :action => session[:intended_action]
    redirect_to root_path
  end

  def login
    if request.post?
      begin
        config = Utils::load_config
        anonymous_login = config['anonymous_login']
        username = params.include?(:username) ? params[:username].to_s : anonymous_login.to_s

        requested_user = ScalarmUser.find_by_login(username)
        raise t('user_controller.login.user_not_found') if requested_user.nil?

        if requested_user.banned_infrastructure?('scalarm')
          raise t('user_controller.login.login_banned', time: requested_user.ban_expire_time('scalarm'))
        end

        session[:user] = ScalarmUser.authenticate_with_password(username, params[:password]).id.to_s

        if requested_user.credentials_failed and requested_user.credentials_failed.include?('scalarm')
          requested_user.credentials_failed['scalarm'] = []
          requested_user.save
        end

        successful_login
      rescue Exception => e
        Rails.logger.debug("Exception on login: #{e}\n#{e.backtrace.join("\n")}")
        reset_session
        flash[:error] = e.to_s

        unless requested_user.nil?
          requested_user.credentials_failed = {} unless requested_user.credentials_failed
          requested_user.credentials_failed['scalarm'] = [] unless requested_user.credentials_failed.include?('scalarm')
          requested_user.credentials_failed['scalarm'] << Time.now
          requested_user.save
        end

        redirect_to login_path
      end
    end
  end

  def logout
    reset_session
    @user_session.destroy unless @user_session.blank?
    @current_user.destroy_unused_credentials unless @current_user.nil?

    flash[:notice] = t('logout_success')

    redirect_to login_path
  end

  def change_password
    if params[:password] != params[:password_repeat]

      flash[:error] = t('password_repeat_error')

    elsif params[:password].length < 6 or (/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.match(params[:password]).nil?)

      flash[:error] = t('password_too_weak')

    elsif (not @current_user.password_hash.nil?)

      begin
        ScalarmUser.authenticate_with_password(@current_user.login, params[:current_password])
      rescue Exception => e
        flash[:error] = t('password_wrong')
      end

    end

    if flash[:error].blank?
      @current_user.password = params[:password]
      @current_user.save

      flash[:notice] = t('password_changed')
    end

    redirect_to :action => 'account'
  end

  def status
    render inline: "Hello world from Scalarm Experiment Manager, it's #{Time.now} at the server!\n"
  end

  # --- OpenID support ---

  private

  # Get stateless mode OpenID::Consumer instance for this controller.
  def consumer
    @consumer ||= OpenID::Consumer.new(session, nil) # 'nil' for stateless mode
  end

end
