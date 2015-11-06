require 'scalarm/service_core/application_helper_extensions'

module ApplicationHelper
  include Scalarm::ServiceCore::ApplicationHelperExtensions

  def button_classes
    'button radius small expand action-button'
  end

  def footer_link_image(image_path, href='#')
    content_tag(:div,
                style: 'height: 40px; float: right; margin-left: 24px;',
                class: 'footer-link-image') do
      link_to(image_tag(image_path, class: 'in-middle fit-to-div'), href)
    end
  end
end
