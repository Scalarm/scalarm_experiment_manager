require 'scalarm/service_core/information_service'

config = Rails.application.secrets

service_url = config['information_service_url']
username = config['information_service_user']
password = config['information_service_pass']
development = !!config['information_service_development']

INFORMATION_SERVICE =
    Scalarm::ServiceCore::InformationService.new(service_url, username, password, development)
