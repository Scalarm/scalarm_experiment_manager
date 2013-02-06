module SimulationsHelper

  def options_for_input_writers
    input_writers = SimulationInputWriter.all

    input_writers.map{|input_writer| [input_writer.name, input_writer.name]}
  end
end
