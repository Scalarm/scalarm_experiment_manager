require 'scalarm/service_core/configuration'
require 'scalarm/service_core/logger'

Scalarm::Database::Logger.register(Rails.logger)
Scalarm::ServiceCore::Logger.set_logger(Rails.logger)
