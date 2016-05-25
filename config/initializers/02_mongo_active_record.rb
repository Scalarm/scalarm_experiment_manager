require 'scalarm/service_core/initializers/mongo_active_record_initializer'

MongoActiveRecordInitializer.start(Rails.application.secrets.database) unless Rails.env.test?
Scalarm::Database::Model::ExperimentProgressNotification.create_capped_collection unless Rails.env.test?

Mongo::Logger.logger       = ::Logger.new(File.join(Rails.root, 'log', 'mongo_driver.log'))
Mongo::Logger.logger.level = ::Logger::FATAL