require 'scalarm/service_core/initializers/mongo_active_record_initializer'

MongoActiveRecordInitializer.start(Rails.application.secrets.database) unless Rails.env.test?
