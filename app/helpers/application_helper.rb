require 'scalarm/service_core/application_helper_extensions'

module ApplicationHelper
  include Scalarm::ServiceCore::ApplicationHelperExtensions

  def button_classes
    'button radius small expand action-button'
  end
end
