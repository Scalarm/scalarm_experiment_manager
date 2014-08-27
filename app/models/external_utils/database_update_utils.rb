module DatabaseUpdateUtils
  def self.convert_strings_to_json
    # Experiment: experiment_input, doe_info,  parameters_constraints
    # Simulation: input_specification
    # SimulationRun: result, cpu_info, tmp_result

    Experiment.all.each do |experiment|
      experiment.experiment_input = Utils.parse_json_if_string(experiment.experiment_input)
      experiment.doe_info = Utils.parse_json_if_string(experiment.doe_info)
      experiment.parameters_constraints = Utils.parse_json_if_string(experiment.parameters_constraints)

      experiment.save
    end

    Simulation.all.each do |simulation|
      simulation.input_specification = Utils.parse_json_if_string(simulation.input_specification)

      simulation.save
    end

    SimulationRun.all.each do |simulation_run|
      simulation_run.result = Utils.parse_json_if_string(simulation_run.result)
      simulation_run.cpu_info = Utils.parse_json_if_string(simulation_run.cpu_info)
      simulation_run.tmp_result = Utils.parse_json_if_string(simulation_run.tmp_result)

      simulation_run.save
    end

    true
  end


end