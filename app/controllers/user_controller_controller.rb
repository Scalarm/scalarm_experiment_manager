require 'openid'
require 'openid/extensions/ax'

require 'openid_providers/google_openid'
require 'openid_providers/plgrid_openid'
require 'openid_providers/github_oauth'

require 'utils'

class UserControllerController < ApplicationController
  include UserControllerHelper
  include GoogleOpenID
  include PlGridOpenID
  include GithubOauth

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
        config = Utils::load_config
        anonymous_login = config['anonymous_login']
        username = params.include?(:username) ? params[:username].to_s : anonymous_login.to_s

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
    keep_session_params(:server_name) do
      reset_session
    end
    @user_session.destroy unless @user_session.blank?
    @current_user.destroy_unused_credentials unless @current_user.nil?

    flash[:notice] = t('logout_success')

    redirect_to login_path
  end

  def change_password
    if params[:password] != params[:password_repeat]

      flash[:error] = t('password_repeat_error')

    elsif params[:password].length < 8 or (/\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.match(params[:password]).nil?)

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
    tests = Utils.parse_json_if_string(params[:tests])

    status = 'ok'
    message = ''

    unless tests.nil?
      failed_tests = tests.select { |t_name| not send("status_test_#{t_name}") }

      unless failed_tests.empty?
        status = 'failed'
        message = "Failed tests: #{failed_tests.join(', ')}"
      end
    end

    http_status = (status == 'ok' ? :ok : :internal_server_error)

    respond_to do |format|
      format.html do
        render text: message, status: http_status
      end
      format.json do
        render json: {status: status, message: message}, status: http_status
      end
    end
  end

  private

  # --- OpenID support ---

  # Get stateless mode OpenID::Consumer instance for this controller.
  def consumer
    @consumer ||= OpenID::Consumer.new(session, nil) # 'nil' for stateless mode
  end

  # --- Status tests ---

  def status_test_database
    MongoActiveRecord.available?
  end

end
