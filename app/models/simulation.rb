# Attributes
#_id:
#name:
#description
#input_specification:
#user_id:
#simulation_binaries_id:
#input_writer_id
#executor_id
#output_reader_id
#progress_monitor_id
#created_at: timestamp

require 'scalarm/database/model/simulation'

class Simulation < Scalarm::Database::Model::Simulation
  attr_join :user, ScalarmUser
  attr_join :input_writer, SimulationInputWriter
  attr_join :executor, SimulationExecutor
  attr_join :output_reader, SimulationOutputReader
  attr_join :progress_monitor, SimulationProgressMonitor
end
