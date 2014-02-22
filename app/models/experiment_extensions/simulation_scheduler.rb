module SimulationScheduler

  def get_next_instance
    create_file_with_ids if not File.exist?(file_with_ids_path)

    begin
      instance_to_check = self.fetch_instance_from_db

      #if instance_to_check
      # instance_to_check.to_sent = false
      # instance_to_check.sent_at = Time.now
      # instance_to_check.save
      #end

      return instance_to_check

    rescue Exception => e
      logger.debug("get_next_instance --- #{e}")
    end

    nil
  end

  # Generate a list of subsequent simulation ids in a random order
  # based on the 'manager_id' attribute and the overall number of registered Experiment Managers
  def create_file_with_ids
    #manager_counter = ExperimentManager.all.size
    manager_counter = 1
    manager_counter = 1 if manager_counter == 0

    id_list = []
    #next_simulation_id = Rails.configuration.manager_id
    next_simulation_id = 1
    next_simulation_id = 1 if next_simulation_id.nil?

    while next_simulation_id <= self.experiment_size
      id_list << next_simulation_id
      next_simulation_id += manager_counter
    end

    id_list.shuffle!

    File.open(file_with_ids_path, 'wb') do |f|
      id_list.each { |num| f << [num].pack('i') }
    end
  end

  def file_with_ids_path
    File.join(Rails.root, 'tmp', "manager_#{Rails.configuration.manager_id}_exp_#{self.id}.dat")
  end

  def fetch_instance_from_db
    #Rails.logger.debug("Scheduling_policy is set to #{self.scheduling_policy}")
    begin
      self.send("#{self.scheduling_policy}_scheduling")
    rescue Exception => e
      Rails.logger.debug("[simulation_scheduler] fetch_instance_from_db --- #{e}")
      nil
    end
  end

  # scheduling policy methods: monte_carlo, sequential_forward, sequential_backward
  def monte_carlo_scheduling
    simulation_id = next_simulation_id_with_seek
    if (not simulation_id.nil?) and simulation_id > 0 and simulation_id <= experiment_size
      return create_new_simulation(simulation_id)
    end


    simulation = simulation_hash_to_sent
    if (not simulation.nil?) and simulation['id'] > 0 and simulation['id'] <= experiment_size
      simulation['to_sent'] = false
      self.save_simulation(simulation)

      return simulation
    end

    simulation_id = naive_partition_based_simulation_hash

    if (not simulation_id.nil?) and simulation_id > 0 and simulation_id <= experiment_size
      create_new_simulation(simulation_id)
    else
      nil
    end
  end

  def next_simulation_id_with_seek
    #Rails.logger.debug('Simulation id with seek')
    next_simulation_id = -1

    while next_simulation_id < 0

      experiment_seek = if not Rails.configuration.experiment_seeks[self.experiment_id].nil?
                          seek = Rails.configuration.experiment_seeks[self.experiment_id]
                          Rails.configuration.experiment_seeks[self.experiment_id] += 1
                          seek
                        else
                          Rails.configuration.experiment_seeks[self.experiment_id] = 1
                          0
                        end

      #Rails.logger.debug("Current experiment seek is #{experiment_seek}")
      next_simulation_id = IO.read(file_with_ids_path, 4, 4*experiment_seek)
      return nil if next_simulation_id.nil?

      next_simulation_id = next_simulation_id.unpack('i').first
      #Rails.logger.debug("Next simulation id is #{next_simulation_id}")
      simulation = self.find_simulation_docs_by({ id: next_simulation_id }, { limit: 1 }).first

      next if simulation.nil? or (simulation['to_sent'] == true)
      next_simulation_id = -1
    end

    next_simulation_id
  end


  def generate_simulation_for(simulation_id)
    combination = []

    id_num = simulation_id - 1
    self.value_list.each_with_index do |tab, index|
      current_index = id_num / self.multiply_list[index]
      combination[index] = tab[current_index]

      id_num -= current_index * self.multiply_list[index]
      # Rails.logger.debug("Index: #{index} - Current index: #{current_index} - Selected Element: #{tab[current_index]} - id_num: #{id_num}")
    end

    columns = %w(id experiment_id is_done to_sent run_index arguments values)
    values = [simulation_id, self._id, false, true, 1, self.parameters.flatten.join(','), combination.join(',')]

    Hash[*columns.zip(values).flatten]
  end

  def simulation_hash_to_sent
    Rails.logger.debug('Simulation which is in to sent state')

    self.find_simulation_docs_by({ to_sent: true }, { limit: 1 }).first
  end

  def naive_partition_based_simulation_hash
    # Rails.logger.debug('Naive partition based simulation')
     partition_start_id = 0
     partition_end_id = experiment_size
     query_hash = { 'id' => { '$gt' => partition_start_id, '$lte' => partition_end_id } }
    
     simulations_in_partition = self.simulations_count_with(query_hash)
    
     if simulations_in_partition != partition_end_id - partition_start_id
       simulation_id = find_unsent_simulation_in(partition_start_id, partition_end_id)
    
       return simulation_id if not simulation_id.nil?
     end
    
    nil
  end

  def find_unsent_simulation_in(partition_start_id, partition_end_id)
    # Rails.logger.debug("Finding unsent simulation between #{partition_start_id} and #{partition_end_id}")

    if partition_end_id - partition_start_id < 200 # conquer
      query_hash = { id: { '$gt' => partition_start_id, '$lte' => partition_end_id } }
      options_hash = { fields: { 'id' => 1, '_id' => 0 }, sort: [ [ 'id', :asc ] ] }

      # getting simulation_run ids from the partition
      simulations_ids = self.find_simulation_docs_by(query_hash, options_hash)#.map{ |x| x['id'] }

      0.upto(partition_end_id - partition_start_id).each do |index|
        correct_id = partition_start_id + index + 1
        actual_id = simulations_ids[index]

        if (actual_id.nil? or actual_id['id'] != correct_id) and
           (is_simulation_ready_to_run(correct_id) == true)

          return correct_id
        end
      end

    else # divide
      middle_of_partition = ((partition_end_id - partition_start_id) / 2) + partition_start_id
      query_hash = { 'id' => { '$gt' => partition_start_id, '$lte' => middle_of_partition } }
      size_of_half_partition = self.simulations_count_with(query_hash)

      if size_of_half_partition < (middle_of_partition - partition_start_id)
        return find_unsent_simulation_in(partition_start_id, middle_of_partition)
      elsif size_of_half_partition == (middle_of_partition - partition_start_id)
        return find_unsent_simulation_in(middle_of_partition, partition_end_id)
      end
    end

    nil
  end

  def sequential_forward_scheduling
    next_simulation_id = 1

    while next_simulation_id <= experiment_size
      if simulation_collection.find_one({ id: next_simulation_id }).nil?
        return create_new_simulation(next_simulation_id)
      else
        next_simulation_id += 1
      end
    end

    nil
  end

  def sequential_backward_scheduling
    next_simulation_id = experiment_size

    while next_simulation_id > 0
      if simulation_collection.find_one({ id: next_simulation_id }).nil?
        return create_new_simulation(next_simulation_id)
      else
        next_simulation_id -= 1
      end
    end

    nil
  end


end