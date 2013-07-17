# Load the rails application
require File.expand_path('../application', __FILE__)
require 'spawn'

Encryptor.default_options.merge!(:key => Digest::SHA256.hexdigest('QjqjFK}7|Xw8DDMUP-O$yp'))

# Initialize the rails application
SimulationManager::Application.initialize!

# Start infrastructure Monitoring
InfrastructureFacade.start_monitoring
# Start experiment watcher
ExperimentWatcher.watch_experiments
