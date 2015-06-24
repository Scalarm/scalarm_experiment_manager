require 'scalarm/service_core/configuration'

anonymous_config = Utils.load_config.anonymous_user

if anonymous_config
  Scalarm::ServiceCore::Configuration.anonymous_login = anonymous_config['login']
  Scalarm::ServiceCore::Configuration.anonymous_password = anonymous_config['password']
end