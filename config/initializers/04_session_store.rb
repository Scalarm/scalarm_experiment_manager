# Be sure to restart your server when you modify this file.

# using MongoStore, connection is initialized in 02_mongo_active_record initializer
ScalarmExperimentManager::Application.config.session_store :mongo_store,
                               key: '_scalarm_session' #,
                               #expire_after:  Rails.configuration.session_threshold.seconds

Rails.application.config.action_dispatch.cookies_serializer = :marshal
