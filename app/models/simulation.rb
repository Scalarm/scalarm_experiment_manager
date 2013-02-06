# Attributes
# name, description => string
# input_writer_id, executor_id, output_reader_id => references
# simulation_binaries_id => references to a file kept in GridFS

class Simulation < MongoActiveRecord

  def self.collection_name
    "simulations"
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

  def set_simulation_binaries(filename, binary_data)
    @attributes["simulation_binaries_id"] = @@grid.put(binary_data, :filename => filename)
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

end
