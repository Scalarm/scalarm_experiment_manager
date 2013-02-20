
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
    @simulation = Simulation.find_by_id params['simulation_id']
    @experiment_input = JSON.parse params['experiment_input']

    @scenario_parametrization = {}
    @experiment_input.each do |entity_group|
      entity_group["entities"].each do |entity|
        entity["parameters"].each do |parameter|
          parameter_uid = "#{entity_group["id"]}#{DataFarmingExperiment::ID_DELIM}#{entity["id"]}#{DataFarmingExperiment::ID_DELIM}#{parameter["id"]}"
          @scenario_parametrization[parameter_uid] = parameter["parametrizationType"]
        end
      end
    end


    @experiment = Experiment.new(:is_running => false,
                                 :instance_index => 0,
                                 :run_counter => 1,
                                 :time_constraint_in_sec => 60,
                                 :time_constraint_in_iter => 100,
                                 :experiment_name => @simulation.name,
                                 :user_id => session[:user],
                                 :parametrization => @scenario_parametrization.map { |k, v| "#{k}=#{v}" }.join(','))

    @experiment.save_and_cache

    data_farming_experiment = DataFarmingExperiment.new({ "experiment_id" => @experiment.id,
                                                          "simulation_id" => @simulation.id,
                                                          "experiment_input" => @experiment_input,
                                                          "name" => @simulation.name,
                                                          "user_id" => session[:user],
                                                          "is_running" => false,
                                                          "run_counter" => 1,
                                                          "time_constraint_in_sec" => 3600
                                                        })
    data_farming_experiment.save

    @experiment.parameters = data_farming_experiment.parametrization_values
    @experiment.arguments = data_farming_experiment.parametrization_values
    @experiment.doe_groups = ""
    @experiment.experiment_size = data_farming_experiment.experiment_size

    @experiment.is_running = true
    @experiment.start_at = Time.now

    @experiment.create_progress_bar

    labels = data_farming_experiment.parameters
    value_list = data_farming_experiment.value_list
    multiply_list = Array.new(value_list.size)
    multiply_list[-1] = 1
    (multiply_list.size - 2).downto(0) do |index|
      multiply_list[index] = multiply_list[index + 1] * value_list[index + 1].size
    end

    ExperimentInstanceDb.default_instance.store_experiment_info(@experiment, labels, value_list, multiply_list)

    @experiment.save_and_cache

    redirect_to :action => :index
  end
end
