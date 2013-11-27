# Attributes
# name, description => string
# input_writer_id, executor_id, output_reader_id => references
# simulation_binaries_id => references to a file kept in GridFS

require_relative 'simulation_elements/simulation_executor'
require_relative 'simulation_elements/simulation_input_writer'
require_relative 'simulation_elements/simulation_output_reader'
require_relative 'simulation_elements/simulation_progress_monitor'

class Simulation < MongoActiveRecord

  def self.collection_name
    'simulations'
  end

  def input_writer
    SimulationInputWriter.find_by_id(self.input_writer_id)
  end

  def executor
    SimulationExecutor.find_by_id(self.executor_id)
  end

  def output_reader
    SimulationOutputReader.find_by_id(self.output_reader_id)
  end

  def progress_monitor
    if self.progress_monitor_id.nil?
      nil
    else
      SimulationProgressMonitor.find_by_id(self.progress_monitor_id)
    end
  end

  def set_simulation_binaries(filename, binary_data)
    @attributes['simulation_binaries_id'] = @@grid.put(binary_data, :filename => filename)
  end

  def simulation_binaries
    @@grid.get(self.simulation_binaries_id).read
  end

  def simulation_binaries_name
    @@grid.get(self.simulation_binaries_id).filename
  end

  def simulation_binaries_size
    @@grid.get(self.simulation_binaries_id).file_length
  end

  def destroy
    @@grid.delete self.simulation_binaries_id
    super
  end

  def prepare_code_base
    #code_base_dir = Dir.mktmpdir('code_base')
    ##begin
    #  # use the directory...
    #  open("#{code_base_dir}/input_writer", 'w') { |f| f.write(self.input_writer.code) }
    #  open("#{code_base_dir}/executor", 'w') { |f| f.write(self.executor.code) }
    #  open("#{code_base_dir}/output_reader", 'w') { |f| f.write(self.output_reader.code) }
    #  open("#{code_base_dir}/simulation_binaries.zip", 'w') { |f| f.write(self.simulation_binaries) }
    ##ensure
    #  # remove the directory.
    #  #FileUtils.remove_entry_secure(code_base_dir)
    ##end
    #code_base_dir
  end

end
