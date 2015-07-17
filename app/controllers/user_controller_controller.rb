require 'openid'
require 'openid/extensions/ax'

require 'openid_providers/google_openid'
require 'openid_providers/plgrid_openid'
require 'openid_providers/github_oauth'

require 'utils'

require 'scalarm/database/core/mongo_active_record'

require 'scalarm/service_core/utils'
require 'scalarm/service_core/status_controller'

class UserControllerController < ApplicationController
  include Scalarm::ServiceCore::StatusController
  include UserControllerHelper
  include GoogleOpenID
  include PlGridOpenID
  include GithubOauth

  ##
  # Normally render welcome page
  # Render trivial json if Accept: application/json specified,
  # for testing and authentication tests purposes
  def index
    Rails.logger.info "index #{current_user}"
    respond_to do |format|
      format.html
      format.json { render json: {status: 'ok',
                                  message: 'Welcome to Scalarm',
                                  user_id: current_user.id.to_s } }
    end
  end

  def status
    super
  end

  def successful_login
    original_url = session[:original_url]
    session[:original_url] = nil

    flash[:notice] = t('login_success')
    Rails.logger.debug('[authentication] successful')

    @user_session = UserSession.create_and_update_session(session[:user].to_s,
                                                          session[:uuid])

    redirect_to (original_url or root_path)
  end

  def login
    if request.post?
      begin
        anonymous_config = Utils::load_config.anonymous_user

        username = if anonymous_config and not params.include?(:username)
                     config['login'].to_s
                   else
                     params[:username].to_s
                   end

        requested_user = ScalarmUser.find_by_login(username)
        raise t('user_controller.login.user_not_found') if requested_user.nil?

        if requested_user.banned_infrastructure?('scalarm')
          raise t('user_controller.login.login_banned', time: requested_user.ban_expire_time('scalarm'))
        end

        session[:user] = ScalarmUser.authenticate_with_password(username, params[:password]).id.to_s
        session[:uuid] = SecureRandom.uuid

        if requested_user.credentials_failed and requested_user.credentials_failed.include?('scalarm')
          requested_user.credentials_failed['scalarm'] = []
          requested_user.save
        end

        successful_login
      rescue => e
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
    keep_session_params(:server_name) do
      reset_session
    end
    user_session.destroy unless user_session.blank?
    current_user.destroy_unused_credentials unless current_user.nil?

    flash[:notice] = t('logout_success')

    redirect_to login_path
  end

  def change_password
    if params[:password] != params[:password_repeat]

      flash[:error] = t('password_repeat_error')

    elsif params[:password].length < 8 or (/\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.match(params[:password]).nil?)

      flash[:error] = t('password_too_weak')

    elsif (not current_user.password_hash.nil?)

      begin
        ScalarmUser.authenticate_with_password(current_user.login, params[:current_password])
      rescue Exception => e
        flash[:error] = t('password_wrong')
      end

    end

    if flash[:error].blank?
      current_user.password = params[:password]
      current_user.save

      flash[:notice] = t('password_changed')
    end

    redirect_to :action => 'account'
  end

  private

  # --- OpenID support ---

  # Get stateless mode OpenID::Consumer instance for this controller.
  def consumer
    @consumer ||= OpenID::Consumer.new(session, nil) # 'nil' for stateless mode
  end


end
