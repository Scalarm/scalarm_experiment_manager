require 'openid'

require 'scalarm/service_core/scalarm_authentication'
require 'scalarm/service_core/parameter_validation'
require 'erb'

class ApplicationController < ActionController::Base
  include Scalarm::ServiceCore::ScalarmAuthentication
  include Scalarm::ServiceCore::ParameterValidation
  include ERB::Util

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session, :except => [:openid_callback_plgrid]

  before_filter :authenticate, :except => [:status, :login, :login_openid_google, :openid_callback_google,
                                           :login_openid_plgrid, :openid_callback_plgrid,
                                           :login_oauth_google, :oauth2_google_callback,
                                           :login_oauth_github, :oauth2_github_callback]

  # due to security reasons (DISABLED)
  # after_filter :set_cache_buster

  rescue_from ValidationError, MissingParametersError, SecurityError, BSON::ObjectId::Invalid,
              InfrastructureErrors::NoCredentialsError, with: :generic_exception_handler

  if Rails.application.secrets.monitoring
    before_filter :start_monitoring, except: [:status]
    after_filter :stop_monitoring, except: [:status]
    @@probe =  MonitoringProbe.new
  end

  ##
  # Query random public url of service of services_name type (plural name)
  def sample_service_url(services_name)
    service_url = nil
    begin
      service_url = InformationService.instance.sample_public_url(services_name)
    rescue => e
      Rails.logger.error "Error accessing InformationService: #{e.to_s}\n#{e.backtrace.join("\n")}"
    end
    service_url
  end

  helper_method :sample_service_url

  protected

  ##
  # Override authenticate to use SclarmUser class from ExperimentManager
  # current_user and user_session should be initialized in Scalarm::ServiceCore::ScalarmAuthentication
  def authenticate
    super
    @current_user = current_user.convert_to(ScalarmUser) if current_user
    @sm_user = sm_user.convert_to(SimulationManagerTempPassword) if sm_user
    @user_session = user_session.convert_to(UserSession) if user_session
  end

  def generic_exception_handler(exception)
    Rails.logger.warn("Exception caught in generic_exception_handler: #{exception.message}")
    Rails.logger.debug("Exception backtrace:\n#{exception.backtrace.join("\n")}")

    respond_to do |format|
      format.html do
        flash[:error] = exception.to_s
        redirect_to action: :index
      end

      format.json do
        render json: {
                        status: 'error',
                        reason: exception.to_s
                     },
               status: 412
      end

      format.js do
        @error_message = exception.to_s
        render partial: '/js_error_handler'
      end
    end
  end

  def authentication_failed
    Rails.logger.debug('[authentication] failed')
    respond_to do |format|
      format.html do
        Rails.logger.debug('[authentication] redirecting to login page')

        session[:original_url] = request.original_url
        #session[:intended_params] = params.to_hash.except('action', 'controller')

        keep_session_params(:server_name, :original_url) do
          reset_session
        end

        flash[:error] = t('login.required')

        redirect_to :login
      end

      format.json do
        Rails.logger.debug('[authentication] 403')

        # Commented out because of SCAL-774 - popular browsers show annoying basic auth popup
        #headers['WWW-Authenticate'] = %(Basic realm="Scalarm")
        render json: {status: 'error', reason: 'Authentication failed'}, status: :unauthorized
      end
    end

  end

  def start_monitoring
    #@probe = MonitoringProbe.new
    @action_start_time = Time.now
  end

  def stop_monitoring
    processing_time = ((Time.now - @action_start_time)*1000).to_i.round
    #Rails.logger.info("[monitoring][#{controller_name}][#{action_name}]#{processing_time}")
    @@probe.send_measurement(controller_name, action_name, processing_time)
  end

  def keep_session_params(*args, &block)
    values = {}
    args.each do |param|
      values[param] = session[param] if session.include? param
    end
    begin
      yield block
    ensure
      values.each do |param, value|
        session[param] = value
      end
    end
  end

  # DEPRECATED due to security reasons
  #def set_cache_buster
    #response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    #response.headers["Pragma"] = "no-cache"
    #response.headers["Server"] = "Scalarm custom server"
    #
    #cookies.each do |key, value|
    #  response.delete_cookie(key)
    #  if value.kind_of?(Hash)
    #    response.set_cookie(key, value.merge!({expires: 6.hour.from_now}))
    #  else
    #    response.set_cookie(key, {value: value, expires: 6.hour.from_now})
    #  end
    #end
  #end

end
