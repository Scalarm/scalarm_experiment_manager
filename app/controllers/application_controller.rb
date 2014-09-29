require 'openid'

class ApplicationController < ActionController::Base
  include ScalarmAuthentication
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :exception

  before_filter :authenticate, :except => [:login, :login_openid_google, :openid_callback_google,
                                           :login_openid_plgrid, :openid_callback_plgrid]
  before_filter :start_monitoring
  after_filter :stop_monitoring

  @@probe = MonitoringProbe.new

  protected

  def authentication_failed
    Rails.logger.debug('[authentication] failed -> redirect')

    reset_session
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
    regexp = case mode
               when :default
                 /^(\w|(-))+$/

               when :openid_id
                 /^(\w|(-)|(\.)|(:)|(\/)|(=))+$/

               else
                 /^$/
             end

    param_names.each do |param_name|
      if params.include?(param_name) and regexp.match(params[param_name]).nil?
        raise SecurityError.new("Insecure parameter given - #{param_name}")
      end
    end
  end

end
