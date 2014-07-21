module ExperimentExtender

  def add_parameter_values(parameter_uid, new_parameter_values)
    Rails.logger.debug("Adding additional values for parameter #{parameter_uid} --- #{new_parameter_values}")
    parameter_doc = self.get_parameter_doc(parameter_uid)

    new_parameter_values = update_doe_info(parameter_uid, new_parameter_values) if parameter_doc['in_doe']

    param_index = -1
    self.parameters.each_with_index do |parameter, index|
      if (parameter.respond_to?('each') and parameter.include?(parameter_uid)) or (parameter == parameter_uid)
        param_index = index
        break
      end
    end

    Rails.logger.debug("Value list: #{self.value_list}")
    Rails.logger.debug("Multiply list: #{self.multiply_list}")

    num_of_new_values = new_parameter_values.size
    Rails.logger.debug("num_of_new_values: #{num_of_new_values}")
    num_of_new_simulations = (self.experiment_size / value_list[param_index].size) * num_of_new_values
    Rails.logger.debug("num_of_new_simulations: #{num_of_new_simulations}")

    num_of_elements_in_iteration = (param_index == multiply_list.size - 1 ? 1 : value_list[param_index + 1..-1].reduce(1) { |acc, tab| acc *= tab.size }) * num_of_new_values
    Rails.logger.debug("num_of_elements_in_iteration: #{num_of_elements_in_iteration}")
    iteration_offset = value_list[param_index..-1].reduce(1) { |acc, tab| acc *= tab.size }
    Rails.logger.debug("iteration_offset: #{iteration_offset}")

    ids_of_new_simulations = generate_ids_for_new_simulations(param_index, num_of_new_simulations, num_of_elements_in_iteration, iteration_offset)
    Rails.logger.debug("ids_of_new_simulations: #{ids_of_new_simulations}")

    unless parameter_doc['in_doe']
      self.value_list_extension = [] if self.value_list_extension.nil?
      self.value_list_extension << [parameter_uid, new_parameter_values]
    end

    self.clear_cached_data

    Rails.logger.debug("New value list: #{self.value_list}")
    Rails.logger.debug("New multiply list: #{self.multiply_list}")

    # UPDATE
    # 1. old fashion experiment - DEPRECATED
    # 2. data farming experiment
    self.save_and_cache
    # 3. simulations id renumeration apply
    Rails.logger.debug("Renumerating existing ids")
    id_change_map = prepare_map_for_simulations_id_change(iteration_offset, num_of_elements_in_iteration)
    self.update_simulations(id_change_map)

    num_of_new_simulations
  end

  def update_doe_info(parameter_uid, new_parameter_values)
    doe_group = self.doe_info.select{|doe_group_tmp| doe_group_tmp[1].include?(parameter_uid)}.first
    Rails.logger.debug("DoE group: #{doe_group}")

    other_doe_parameter_values = []
    doe_group[1].each_with_index do |other_parameter_uid, index|
      if other_parameter_uid == parameter_uid
        other_doe_parameter_values[index] = nil
      else
        other_doe_parameter_values[index] = []
      end
    end

    doe_group[2].each_with_index do |list_of_values, index|
      list_of_values.each_with_index do |value, value_index|
        other_doe_parameter_values[value_index] += [ value ] unless other_doe_parameter_values[value_index].nil?
      end
    end

    other_doe_parameter_values = other_doe_parameter_values.map{|list_of_values| list_of_values.uniq unless list_of_values.nil?}
    Rails.logger.debug("Other DoE parameters: #{other_doe_parameter_values}")
    other_doe_parameter_values[other_doe_parameter_values.index(nil)] = new_parameter_values
    new_combinations = other_doe_parameter_values[1..-1].reduce(other_doe_parameter_values[0]){|acc, next_list| acc.product(next_list)}.map(&:flatten)
    Rails.logger.debug("Product: #{new_combinations}")

    Rails.logger.debug("DoE info: #{self.doe_info}")

    self.doe_info.each_with_index do |doe_group, index|
      if doe_group[1].include?(parameter_uid)
        doe_group[2] += new_combinations
        self.doe_info[index] = doe_group
      end
    end

    Rails.logger.debug("New DoE info: #{self.doe_info}")
    new_combinations
  end

  def generate_ids_for_new_simulations(param_index, num_of_new_simulations, num_of_elements_in_iteration, iteration_offset)
    start_index = (param_index == 0 ? self.experiment_size : multiply_list[param_index - 1])
    Rails.logger.debug("start_index: #{start_index}")

    ids_of_new_simulations = []

    while (num_of_new_simulations > 0)
      1.upto(num_of_elements_in_iteration) do |i|
        ids_of_new_simulations << start_index + i
      end

      start_index += num_of_elements_in_iteration + iteration_offset
      num_of_new_simulations -= num_of_elements_in_iteration
    end

    ids_of_new_simulations.sort
  end

  def prepare_map_for_simulations_id_change(iteration_offset, num_of_elements_in_iteration)
    id_change_map = {}

    id_add_factor = 0
    next_id_to_renumerate = 1
    while next_id_to_renumerate <= self.experiment_size
      Rails.logger.debug("Next range to renumerate: #{next_id_to_renumerate} .. #{next_id_to_renumerate + iteration_offset - 1}")

      next_id_to_renumerate.upto(next_id_to_renumerate + iteration_offset - 1) do |simulation_id|
        id_change_map[simulation_id] = simulation_id + id_add_factor
      end

      id_add_factor += num_of_elements_in_iteration
      next_id_to_renumerate += iteration_offset
    end

    id_change_map
  end

  # id_change_map contains information how simulations ids should be updated
  # we need to iterate through existing simulations and update them
  def update_simulations(id_change_map)
    Rails.logger.debug("Size of new ids: #{id_change_map.size}")


    self.find_simulation_docs_by({ }, { sort: [ ['id', :desc] ] }).each do |simulation_run|
      new_simulation_id = id_change_map[simulation_run['id']]

      Rails.logger.debug("Simulation id: #{simulation_run['id']} -> #{new_simulation_id}")
      simulation_run['id'] = new_simulation_id
      self.save_simulation(simulation_run)
    end


    #id_change_map.keys.sort.reverse.each do |old_simulation_id|
    #  new_simulation_id = id_change_map[old_simulation_id]
    #  Rails.logger.debug("Simulation id: #{old_simulation_id} -> #{new_simulation_id}")
    #  # make the actual change
    #  unless old_simulation_id == new_simulation_id
    #    simulation = self.find_simulation_docs_by({id: old_simulation_id}, {limit: 1}).first
    #    unless simulation.nil?
    #      simulation['id'] = new_simulation_id
    #      self.save_simulation(simulation)
    #    end
    #  end
    #end
  end

end