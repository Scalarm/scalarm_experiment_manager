require 'openssl'
require 'net/https'

require 'scalarm/service_core/information_service'

class InformationService < Scalarm::ServiceCore::InformationService
  def instance
    @instance ||= create_from_config
  end

  def create_from_config
    config = Rails.application.secrets

    service_url = config['information_service_url']
    username = config['information_service_user']
    password = config['information_service_pass']
    development = !!config['information_service_development']

    Scalarm::ServiceCore::InformationService.new(service_url, username, password, development)
  end
end
