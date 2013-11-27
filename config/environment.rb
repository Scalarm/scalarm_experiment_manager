# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
ScalarmExperimentManager::Application.initialize!

Encryptor.default_options.merge!(:key => Digest::SHA256.hexdigest('QjqjFK}7|Xw8DDMUP-O$yp'))

