module DatabaseUpdateUtils
  def self.convert_strings_to_json
    # Experiment: experiment_input, doe_info,  parameters_constraints
    # Simulation: input_specification
    # SimulationRun: result, cpu_info, tmp_result

    Experiment.all.each do |experiment|
      begin
        experiment.experiment_input = Utils.parse_json_if_string(experiment.experiment_input)
        experiment.doe_info = Utils.parse_json_if_string(experiment.doe_info)
        experiment.parameters_constraints = Utils.parse_json_if_string(experiment.parameters_constraints)

        experiment.save


       SimulationRunFactory.
            for_experiment(experiment.id).all.each do |simulation_run|
              begin
                simulation_run.result = Utils.parse_json_if_string(simulation_run.result)
                simulation_run.cpu_info = Utils.parse_json_if_string(simulation_run.cpu_info)
                simulation_run.tmp_result = Utils.parse_json_if_string(simulation_run.tmp_result)

                simulation_run.save
              rescue Exception => e
                puts "Exception: #{e.class}, #{e.to_s} on simulation run: #{simulation.id}"
              end
        end

      rescue Exception => e
        puts "Exception: #{e.class}, #{e.to_s} on experiement: #{experiment.id}"
      end
    end

    Simulation.all.each do |simulation|
      begin
        simulation.input_specification = Utils.parse_json_if_string(simulation.input_specification)

        simulation.save
      rescue Exception => e
        puts "Exception: #{e.class}, #{e.to_s} on simulation: #{simulation.id}"
      end
    end

    true
  end

  # In the past, some fields has *_id name but was not foreign keys
  # this caused problems with foreign keys auto-convert on where
  def self.rename_old_id_fields
    rename_field(DummyRecord, 'res_id', 'res_name')
    rename_field(CloudImageSecrets, 'image_id', 'image_name')
    rename_field(CloudVmRecord, 'vm_id', 'vm_identifier')
    rename_field(PlGridJob, 'grant_id', 'grant_identifier')
    rename_field(PlGridJob, 'job_id', 'job_identifier')
  end

  def self.rename_field(collection_class, old_name, new_name)
    collection_class.each do |record|
      record.send("#{new_name}=", record.send(old_name))
      record._delete_attribute(old_name)
      record.save
    end
  end

end