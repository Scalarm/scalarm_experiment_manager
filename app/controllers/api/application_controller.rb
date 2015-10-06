class Api::ApplicationController < ActionController::API
  include ScalarmAuthentication
  include ParameterValidation
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  before_filter :authenticate

  rescue_from ValidationError, MissingParametersError, SecurityError, BSON::InvalidObjectId, with: :generic_exception_handler

  protected

  def generic_exception_handler(exception)
    Rails.logger.warn("Exception caught in generic_exception_handler: #{exception.message}")
    Rails.logger.debug("Exception backtrace:\n#{exception.backtrace.join("\n")}")

    render json: { reason: exception.to_s }, status: :precondition_failed
  end

  def authentication_failed
    Rails.logger.debug('[authentication] failed - 401')

    headers['WWW-Authenticate'] = %(Basic realm="Scalarm")

    render json: { reason: 'Authentication failed' }, status: :unauthorized
  end

  def validate(validators)
    validate_params(params, validators)
  end

end