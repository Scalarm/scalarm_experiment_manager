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
    manager_counter = ExperimentManager.all.size
    manager_counter = 1 if manager_counter == 0

    id_list = []
    next_simulation_id = Rails.configuration.manager_id

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
    begin
      self.send("#{self.scheduling_policy}_scheduling")
    rescue Exception => e
      Rails.logger.debug("[simulation_scheduler] fetch_instance_from_db --- #{e}")
      nil
    end
  end

  # scheduling policy methods: monte_carlo, sequential_forward, sequential_backward
  def monte_carlo_scheduling
    db = ExperimentInstanceDb.default_instance

    value_list, multiply_list = self.value_list, self.multiply_list

    simulation_id = next_simulation_id_with_seek(db)
    return create_new_simulation(simulation_id, value_list, multiply_list) if not simulation_id.nil?

    simulation_hash = simulation_hash_to_sent(db)
    if not simulation_hash.nil?
      simulation = ExperimentInstance.new(simulation_hash)
      simulation.to_sent = false
      simulation.save
      return simulation
    end

    simulation_id = naive_partition_based_simulation_hash(db)

    return simulation_id.nil? ? nil : create_new_simulation(simulation_id, value_list, multiply_list)
  end

  def next_simulation_id_with_seek(db)
    Rails.logger.debug('Simulation id with seek')
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

      Rails.logger.debug("Current experiment seek is #{experiment_seek}")
      next_simulation_id = IO.read(file_with_ids_path, 4, 4*experiment_seek)
      return nil if next_simulation_id.nil?

      next_simulation_id = next_simulation_id.unpack('i').first
      Rails.logger.debug("Next simulation id is #{next_simulation_id}")
      result_doc = db.find_one_with_order(self.experiment_id, {'id' => next_simulation_id})

      next if result_doc.nil? or (result_doc['to_sent'] == true)
      next_simulation_id = -1
    end

    next_simulation_id
  end

  def create_new_simulation(instance_id, value_list, multiply_list)
    combination = []

    id_num = instance_id - 1
    value_list.each_with_index do |tab, index|
      current_index = id_num / multiply_list[index]
      combination[index] = tab[current_index]

      id_num -= current_index * multiply_list[index]
      # Rails.logger.debug("Index: #{index} - Current index: #{current_index} - Selected Element: #{tab[current_index]} - id_num: #{id_num}")
    end

    columns = %w(id experiment_id is_done to_sent run_index arguments values sent_at)
    values = [instance_id, self.experiment_id, false, false, 1, self.argument_names, combination.join(','), Time.now]

    instance_hash = Hash[*columns.zip(values).flatten]
    #Rails.logger.debug("Inserting as simulation: #{instance_hash}")
    # Rails.logger.debug("instance_hash: #{instance_hash.inspect}")
    instance = ExperimentInstance.new(instance_hash)
    instance.save

    instance
  end

  def simulation_hash_to_sent(db)
    Rails.logger.debug('Simulation which is in to sent state')

    db.find_one_with_order(self.experiment_id, {'to_sent' => true})
  end

def naive_partition_based_simulation_hash(db)
    Rails.logger.debug('Naive partition based simulation')

    manager_counter = ExperimentManager.all.size
    manager_counter = 1 if manager_counter == 0

    partitions_to_check = 1.upto(manager_counter).to_a.shuffle
    partition_size = self.experiment_size / manager_counter

    partitions_to_check.each do |partition_id|
      partition_start_id = partition_size * (partition_id - 1)
      partition_end_id = (partition_id == manager_counter) ? self.experiment_size : partition_start_id + partition_size
      query_hash = { 'id' => { '$gt' => partition_start_id, '$lte' => partition_end_id } }

      simulations_in_partition = db.count_with_query(self.experiment_id, query_hash)
      if simulations_in_partition != partition_end_id - partition_start_id
        Rails.logger.debug("Partition size is #{simulations_in_partition} but should be #{partition_end_id - partition_start_id}")

        simulation_id = find_unsent_simulation_in(partition_start_id, partition_end_id, db)

        return simulation_id if not simulation_id.nil?
      end
    end

    nil
  end

  def is_simulation_ready_to_run(simulation_id, db)
    simulation_doc = db.find_one_with_order(self.experiment_id, {'id' => simulation_id})
    Rails.logger.debug("Simulation #{simulation_id} is nil ? #{simulation_doc.nil?}")

    simulation_doc.nil? or simulation_doc['to_sent']
  end

  def find_unsent_simulation_in(partition_start_id, partition_end_id, db)
    Rails.logger.debug("Finding unsent simulation between #{partition_start_id} and #{partition_end_id}")

    if partition_end_id - partition_start_id < 200 # conquer
      query_hash = { 'id' => { '$gt' => partition_start_id, '$lte' => partition_end_id } }
      options_hash = { :fields => { 'id' => 1, '_id' => 0 }, :sort => [ [ 'id', :asc ] ] }

      simulations_ids = db.find(self.experiment_id, query_hash, options_hash).map{|x| x['id']}
      if simulations_ids.first != partition_start_id + 1
        return partition_start_id + 1 if is_simulation_ready_to_run(partition_start_id + 1, db)
      end

      if simulations_ids.last != partition_end_id
        return partition_end_id if is_simulation_ready_to_run(partition_end_id, db)
      end

      simulations_ids.each_with_index do |element, index|
        simulation_id = partition_start_id + index + 1

        if element != simulation_id
          return simulation_id if is_simulation_ready_to_run(simulation_id, db)
        end
      end

    else # divide
      middle_of_partition = ((partition_end_id - partition_start_id) / 2) + partition_start_id
      query_hash = { 'id' => { '$gt' => partition_start_id, '$lte' => middle_of_partition } }
      size_of_half_partition = db.count_with_query(self.experiment_id, query_hash)

      if size_of_half_partition < (middle_of_partition - partition_start_id)
        return find_unsent_simulation_in(partition_start_id, middle_of_partition, db)
      elsif size_of_half_partition == (middle_of_partition - partition_start_id)
        return find_unsent_simulation_in(middle_of_partition, partition_end_id, db)
      end
    end

    nil
  end

  # TODO FIXME - repair
  def sequential_forward_scheduling
    monte_carlo_scheduling
  end

  def sequential_backward_scheduling
    monte_carlo_scheduling
  end


end