# Load the rails application
require File.expand_path('../application', __FILE__)
require 'spawn'

# Initialize the rails application
SimulationManager::Application.initialize!

# Start infrastructure Monitoring
InfrastructureFacade.start_monitoring
# Start experiment watcher
ExperimentWatcher.watch_experiments
