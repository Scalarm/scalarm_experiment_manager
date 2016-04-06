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

  # Inserts a loading.gif (original size) which is initially hidden
  # using 'loading_chart_gif' class
  # @param [String] id id of result <img> element
  # @return [String] HTML code of <img> with loading.gif
  def loading_gif(id)
    image_tag(image_url('loading.gif'),
              class: 'loading_chart_gif', id: id,
              style: 'display: none;')
  end
end
