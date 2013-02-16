
class SimulationsController < ApplicationController

  def index
    @simulations = Simulation.all
    @input_writers = SimulationInputWriter.all
    @executors = SimulationExecutor.all
    @output_readers = SimulationOutputReader.all
  end

  def registration

  end

  def upload_component
    if params["component_type"] == "input_writer"
      input_writer = SimulationInputWriter.new({:name => params["component_name"], :code => params["component_code"].read})
      input_writer.save
    elsif params["component_type"] == "executor"
      executor = SimulationExecutor.new({:name => params["component_name"], :code => params["component_code"].read})
      executor.save
    elsif params["component_type"] == "output_reader"
      output_reader = SimulationOutputReader.new({:name => params["component_name"], :code => params["component_code"].read})
      output_reader.save
    end

    redirect_to :action => :index
  end

  def destroy_component
    if params["component_type"] == "input_writer"
      SimulationInputWriter.find_by_id(params["component_id"]).destroy
    elsif params["component_type"] == "executor"
      SimulationExecutor.find_by_id(params["component_id"]).destroy
    elsif params["component_type"] == "output_reader"
      SimulationOutputReader.find_by_id(params["component_id"]).destroy
    end

    redirect_to :action => :index
  end

  def upload_simulation
    simulation = Simulation.new({
        "input_writer_id" => params["input_writer_id"],
        "executor_id" => params["executor_id"],
        "output_reader_id" => params["output_reader_id"],
        "name" => params["simulation_name"],
        "description" => params["simulation_description"],
        "input_specification" => params["simulation_input"].read
                   })
    simulation.set_simulation_binaries(params["simulation_binaries"].original_filename, params["simulation_binaries"].read)

    simulation.save

    redirect_to :action => :index
  end

  def destroy_simulation
    Simulation.find_by_id(params["component_id"]).destroy
    redirect_to :action => :index
  end

  # following methods are used in experiment conducting
  require 'json'

  def conduct_experiment
    @simulation = Simulation.find_by_id(params[:simulation_id])
    @simulation_input = JSON.parse(@simulation.input_specification)

  end

  def start_experiment

    redirect_to :action => :index
  end
end
