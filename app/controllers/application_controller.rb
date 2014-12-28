require 'openid'

class ApplicationController < ActionController::Base
  include ScalarmAuthentication
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session, :except => [:openid_callback_plgrid, :openid_callback_google]

  before_filter :authenticate, :except => [:status, :login, :login_openid_google, :openid_callback_google,
                                           :login_openid_plgrid, :openid_callback_plgrid]
  before_filter :start_monitoring
  after_filter :stop_monitoring

  # due to security reasons (DISABLED)
  # after_filter :set_cache_buster

  rescue_from SecurityError, BSON::InvalidObjectId, with: :generic_exception_handler

  @@probe = MonitoringProbe.new


  protected

  def generic_exception_handler(exception)
    Rails.logger.warn("Exception caught in generic_exception_handler: #{exception.message}")
    Rails.logger.debug("Exception backtrace:\n#{exception.backtrace.join("\n")}")
    flash[:error] = exception.message

    respond_to do |format|
      format.html { redirect_to action: :index }
      format.json { render json: {status: 'error', reason: flash[:error]}, status: 412 }
    end
  end

  def authentication_failed
    Rails.logger.debug('[authentication] failed -> redirect')

    reset_session
    @user_session.destroy unless @user_session.nil?

    flash[:error] = t('login.required')
    session[:intended_action] = action_name
    session[:intended_controller] = controller_name

    redirect_to :login
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

  def validate_params(mode, *param_names)
    regexp = Utils::get_validation_regexp(mode)

    param_names.each do |param_name|
      if params.include?(param_name) and regexp.match(params[param_name]).nil?
        raise SecurityError.new(t('errors.insecure_parameter', param_name: param_name))
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
