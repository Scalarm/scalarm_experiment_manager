require "experiment_progress_bar"
require "set"

class Experiment < ActiveRecord::Base
  belongs_to :user
  has_many :experiment_instances
  has_one :experiment_progress_bar
  
  attr_accessor :parametrization_info, :progress_bar, :data_farming_experiment

  PROGRESS_BAR_THRESHOLD = 10000
  
  def self.find_in_db(experiment_id)
    experiment_id = experiment_id.to_i
    experiment_hash = ExperimentInstanceDb.default_instance.get_experiment_info(experiment_id)
    
    if not experiment_hash.nil?
      additional_info = {
        "labels" => experiment_hash["labels"], 
        "value_list" => experiment_hash["value_list"], 
        "multiply_list" => experiment_hash["multiply_list"]
      }
      
      experiment_hash.delete("experiment_id")
      experiment_hash.delete("_id")
      experiment_hash.delete("labels")
      experiment_hash.delete("value_list")
      experiment_hash.delete("multiply_list")
      
      e = Experiment.new(experiment_hash)
      e.id = experiment_id
      e.parametrization_info = additional_info
      e.experiment_progress_bar = ExperimentProgressBar.new({:experiment_id => e.id})

      e.data_farming_experiment = DataFarmingExperiment.find_by_experiment_id(experiment_id)
      
      return e
    end
    
    nil
  end

  def experiment_size
    if not data_farming_experiment.nil?
      data_farming_experiment.experiment_size
    else
      super
    end
  end
=begin
  
  # cache related buggy functions 
  
  def self.find(id)
    cached = Rails.cache.read("experiment_#{id}")
    
    if cached.nil?
      # Rails.logger.debug("Experiment #{id} NOT IN CACHE")
      # cached = Experiment.find_by_id(id, :include => [:experiment_progress_bar])
      cached = Experiment.find_by_id(id)
      Rails.cache.write("experiment_#{id}", cached, :expires_in => 600.seconds)
    else
      # Rails.logger.debug("Experiment #{id} IN CACHE")
    end
    
    cached
  end
  
  def experiment_progress_bar
    cache_key = "progress_bar_#{self.id}"
    cached = Rails.cache.read(cache_key)
    
    if cached.nil?
      # Rails.logger.debug("ProgressBar for experiment #{self.id} NOT IN CACHE")
      cached = ExperimentProgressBar.find_by_experiment_id(self.id)
      Rails.cache.write(cache_key, cached, :expires_in => 600.seconds)
    else
      # Rails.logger.debug("ProgressBar for experiment #{self.id} IN CACHE")
    end
    
    cached
  end
  
=end
  
  def save_and_cache
    Rails.cache.write("experiment_#{id}", self, :expires_in => 600.seconds)
    self.save 
  end

  def get_statistics
    all  = ExperimentInstance.count_with_query(self.id)
    done = ExperimentInstance.count_with_query(self.id, {"is_done" => true})
    sent = ExperimentInstance.count_with_query(self.id, {"to_sent" => false, "is_done" => false})

    return all, done, sent
  end

  def argument_names
    first_instance = ExperimentInstance.find_by_id(self.id, 1)

    first_instance.arguments.split(",").map{|arg| ParameterForm.parameter_uid_for_r(arg)}.join(",")
  end

  def range_arguments
    self.parametrization.split(",").select{|x| x.split("=").last == "range"}.
                                    map{|x| ParameterForm.parameter_uid_for_r(x.split("=").first)}
  end

  def parametrization_of(parameter_r_id)
    self.parametrization.split(",").each do |param_parametrization|
      parameter_uid, parametrization_type = param_parametrization.split("=")

      return parameter_uid, parametrization_type if ParameterForm.parameter_uid_for_r(parameter_uid) == parameter_r_id
    end

    nil
  end

  def generated_parameter_values_for(parameter_uid)
    instance = ExperimentInstance.find_by_id(self.id, 1)
    
    Rails.logger.debug("Parameter UID: #{parameter_uid}")
    Rails.logger.debug("instance.arguments: #{instance.arguments.split(",").map{|x| ParameterForm.parameter_uid_for_r(x)}}")
    
    param_index = instance.arguments.split(",").map{|x| ParameterForm.parameter_uid_for_r(x)}.index(parameter_uid)
    param_value = instance.values.split(",")[param_index]

    find_exp = "^"
    find_exp += "(\\d+\\.\\d+,){#{param_index}}" if param_index > 0
    find_exp = /#{find_exp}#{param_value}/

    query_hash = { "values" => { "$not" => find_exp }}
    option_hash = {:fields => ["values"]}

    param_values = ExperimentInstance.raw_find_by_query(self.id, query_hash, option_hash).
        map{|x| x["values"].split(",")[param_index]}.uniq + [param_value]

    param_values.map{|x| x.to_f}.sort
  end

  def self.running_experiments
    Experiment.where(:is_running => true).all(:order => "start_at DESC").to_a
  end

  def file_with_ids_path
    File.join(Rails.root, "tmp", "manager_#{Rails.configuration.manager_id}_exp_#{self.id}.dat")
  end

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

  def fetch_instance_from_db
    begin
      self.send(self.scheduling_policy + "_scheduling")
    rescue Exception => e
      logger.debug("get_next_instance --- #{e}")
      nil
    end
  end

  def experiment_file_path
    File.join(self.data_folder_path, self.experiment_file)
  end

  def data_folder_path
    if self.experiment_file != nil then
      File.join(Rails.configuration.eusas_data_path, self.experiment_file.split('.')[0])
    else
      nil
    end
  end

  def self.experiments_info(conditions)
    ids = ActiveRecord::Base.connection.select_values("SELECT id FROM experiments WHERE #{conditions}")

    return [], [], [] if ids.empty?
    # TODO FIMXE should work but in the background
    dones = []
    ids.each do |experiment_id|
      dones << 0
      #dones << ExperimentInstance.count_with_query(experiment_id, { "is_done" => true })
    end

    sql = "SELECT id, experiment_size, vm_counter, start_at, experiment_name, end_at " +
        "FROM experiments WHERE id IN (#{ids.join(",")})"
    experiment_info = {}
    ActiveRecord::Base.connection.execute(sql).each do |row|
      experiment_info[row[0]] = row[1..5]
    end

    return ids, dones, experiment_info
  end

  def create_progress_bar
    progress_bar = ExperimentProgressBar.create(:experiment_id => self.id)
    progress_bar.insert_initial_bar(self.experiment_size)
    
    progress_bar.save
  end

  def result_file
    File.join(self.data_folder_path, "results.csv")
  end
  
  def result_file_for_moe(moe_name)
    File.join(self.data_folder_path, "results-#{moe_name}.csv")
  end

  def moe_names
    moe_name_set = Set.new
    
    ExperimentInstance.raw_find_by_query(self.id, { "is_done" => true }, { :fields => ["result"], :limit => (self.experiment_size / 2) }).each do |instance_doc|
      instance_doc["result"].split(",").each{ |x| moe_name_set.add(x.split("=")[0]) }
    end
    
    moe_name_set.empty? ? nil : moe_name_set.to_a
  end

  def result_names
    moe_name_set = Set.new
    result_limit = self.experiment_size < 5000 ? self.experiment_size : (self.experiment_size / 2)

    ExperimentInstance.raw_find_by_query(self.id, { is_done: true }, { fields: 'result', limit: result_limit }).each do |simulation_doc|
      moe_name_set += simulation_doc['result'].keys
    end

    moe_name_set.empty? ? nil : moe_name_set.to_a
  end

  def create_result_file
    File.delete(self.result_file) if File.exist?(self.result_file)

    File.open(self.result_file, "w+") do |f|
      # writing arguments' and moes' names from the first done instance
      moes = ExperimentInstance.get_first_done(self.id).result.split(",").map { |i| i.split("=")[0] }.join(",")
      f.puts("#{argument_names},#{moes}")

      # getting every completed instance and writes input parameters' values and results' values
      ExperimentInstance.raw_find_by_query(self.id, { "is_done" => true }, {:fields => ["values","result"]}).each do |instance_doc|
        # Rails.logger.debug { "Instance Id: #{instance_doc["id"]} --- Input size: #{instance_doc["values"].split(",").size} --- Results size: #{instance_doc["result"].split(',').map { |item| item.split("=")[1] }.size}" }
        f.puts("#{instance_doc["values"]},#{instance_doc["result"].split(',').map { |item| item.split("=")[1] }.join(",")}")
      end
    end

  end
  
  def create_result_file_for(moe_name)
    file_name = result_file_for_moe(moe_name)
    File.delete(file_name) if File.exist?(file_name)

    File.open(file_name, "w+") do |f|
      # writing arguments' and moe names from the first done instance
      f.puts("#{argument_names},#{moe_name}")

      # getting every completed instance and writes input parameters' values and results' values
      
      ExperimentInstance.raw_find_by_query(self.id, { "is_done" => true }, {:fields => ["values","result"]}).each do |instance_doc|
        moe_name_index = instance_doc["result"].index("#{moe_name}")
        next if moe_name_index.nil?
        
        last_index = (instance_doc["result"].index(",", moe_name_index)).nil? ? instance_doc["result"].size : instance_doc["result"].index(",", moe_name_index) 
        moe_value = instance_doc["result"][(moe_name_index+moe_name.size+1)...last_index]
        f.puts("#{instance_doc["values"]},#{moe_value}")
      end
    end
    
    file_name
  end
  
  def create_result_file_for_scatter_plot(x_axis, y_axis)
    file_name = File.join(self.data_folder_path, "results-scatter-#{x_axis}-#{y_axis}.csv")
    
    File.open(file_name, "w+") do |f|
      f.puts("#{x_axis},#{y_axis}")
      
      x_axis_index = (argument_names.include?(x_axis+",") or argument_names.include?(","+x_axis)) ? argument_names.split(",").index(x_axis) : nil
      y_axis_index = (argument_names.include?(y_axis+",") or argument_names.include?(","+y_axis)) ? argument_names.split(",").index(y_axis) : nil   
      
      ExperimentInstance.raw_find_by_query(self.id, { "is_done" => true }, {:fields => ["values","result"]}).each do |instance_doc|
        x_axis_value = if x_axis_index 
            instance_doc["values"].split(",")[x_axis_index]
          else
            moe_name_index = instance_doc["result"].index("#{x_axis}")
            next if moe_name_index.nil?
            
            last_index = (instance_doc["result"].index(",", moe_name_index)).nil? ? instance_doc["result"].size : instance_doc["result"].index(",", moe_name_index) 
            instance_doc["result"][(moe_name_index+x_axis.size+1)...last_index]
          end
        
        y_axis_value = if y_axis_index 
            instance_doc["values"].split(",")[y_axis_index]
          else
            moe_name_index = instance_doc["result"].index("#{y_axis}")
            next if moe_name_index.nil?
            
            last_index = (instance_doc["result"].index(",", moe_name_index)).nil? ? instance_doc["result"].size : instance_doc["result"].index(",", moe_name_index) 
            instance_doc["result"][(moe_name_index+y_axis.size+1)...last_index]
          end      
        
        f.puts("#{x_axis_value},#{y_axis_value}")
      end
    end
    
    file_name
  end

  def completed_simulations_count_for(secs)
    query = { "is_done" => true, "done_at" => { "$gte" => (Time.now - secs)} }

    ExperimentInstance.count_with_query(self.id, query)
  end
  
  def make_simulation_logs_dir
    begin
      Dir::mkdir(self.data_folder_path) if not File.exists?(self.data_folder_path)
    rescue Exception => e
      logger.debug("Error: make_simulation_logs_dir - #{e.inspect}")
    end
  end
  
  def create_parameters_and_doe_groups(params_tab = nil)
     if not params_tab.nil?
       params_to_override, params_groups_for_doe = params_tab 
     else
       params_to_override = self.parameters.split("|").map{ |x| x.split("=") }
       params_groups_for_doe = self.doe_groups.split("|").map{ |x| x.split("=") }
     end

     begin
      parameters = DataFarmingScenario.get_and_override_parameters(self, params_to_override)
      #Rails.logger.debug("\nparameters = #{parameters}\n")
      doe_groups = DataFarmingScenario.create_groups_for_doe(params_groups_for_doe, parameters)
      #Rails.logger.debug("\ndoe_groups = #{doe_groups}\n")
     rescue Exception => e
       Rails.logger.debug("Error while creating parameters and doe groups --- #{e}")
       return [], []
     end

     return parameters, doe_groups
  end
  
  def generate_instance_configurations(start_id = 0)
    ExperimentInstanceDb.create_table_for(self.id)
    parameters, doe_groups = self.create_parameters_and_doe_groups

    return [], [] if parameters.size + doe_groups.size == 0

    counter, index_list, labels, value_list = prepare_factors_for_instance_generation(parameters, doe_groups)
    #Rails.logger.debug("=========== prepare_factors_for_instance_generation")
    #Rails.logger.debug("= index_list - #{index_list.inspect}")

    #value_list.each do |list|
    #  Rails.logger.debug(list.inspect)
    #end

    Rails.logger.debug("= labels.size - #{labels.size}")
    Rails.logger.debug("= value_list.size - #{value_list.size}")

    a = Time.now
    multiply_list = Array.new(value_list.size)
    multiply_list[-1] = 1
    (multiply_list.size - 2).downto(0) do |index|
      multiply_list[index] = multiply_list[index + 1] * value_list[index + 1].size
    end
    Rails.logger.debug("Time of preparing multiply_list: #{Time.now - a}")
    
    ExperimentInstanceDb.default_instance.store_experiment_info(self, labels, value_list, multiply_list)
  end

  def progress_bar_update(simulation_id, update_type)
    return if self.experiment_size < PROGRESS_BAR_THRESHOLD and update_type == "sent"

    parts_per_slot = parts_per_progress_bar_slot
    bar_index = ((simulation_id - 1) / parts_per_slot).floor

    increment_value = if update_type == "done"
                        (self.experiment_size < PROGRESS_BAR_THRESHOLD) ? 1 : 2
                      elsif update_type == "sent"
                        1
                      elsif update_type == "rollback"
                        -1
                      end

    begin
      progress_bar_table.update({:bar_num => bar_index}, "$inc" => {:bar_state => increment_value})
    rescue Exception => e
      Rails.logger.debug("Error in fastest update --- #{e}")
    end
  end

  # ======================= PRIVATE METHODS =============================
  private

  # scheduling policy methods: monte_carlo, sequential_forward, sequential_backward
  def monte_carlo_scheduling
    db = ExperimentInstanceDb.default_instance
     
    value_list, multiply_list = @parametrization_info["value_list"], @parametrization_info["multiply_list"]

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
    Rails.logger.debug("Simulation id with seek")
    next_simulation_id = -1

    while next_simulation_id < 0

      experiment_seek = if not Rails.configuration.experiment_seeks[self.id].nil?
                          seek = Rails.configuration.experiment_seeks[self.id]
                          Rails.configuration.experiment_seeks[self.id] += 1
                          seek
                        else
                          Rails.configuration.experiment_seeks[self.id] = 1
                          0
                        end

      Rails.logger.debug("Current experiment seek is #{experiment_seek}")
      next_simulation_id = IO.read(file_with_ids_path, 4, 4*experiment_seek)
      return nil if next_simulation_id.nil?

      next_simulation_id = next_simulation_id.unpack("i").first
      Rails.logger.debug("Next simulation id is #{next_simulation_id}")
      result_doc = db.find_one_with_order(self.id, {"id" => next_simulation_id})

      next if result_doc.nil? or (result_doc["to_sent"] == true)
      next_simulation_id = -1
    end

    next_simulation_id
  end

  def simulation_hash_to_sent(db)
    Rails.logger.debug("Simulation which is in to sent state")

    db.find_one_with_order(self.id, {"to_sent" => true})
  end

  def naive_partition_based_simulation_hash(db)
    Rails.logger.debug("Naive partition based simulation")

    manager_counter = ExperimentManager.count

    partitions_to_check = 1.upto(manager_counter).to_a.shuffle
    partition_size = self.experiment_size / manager_counter

    partitions_to_check.each do |partition_id|
      partition_start_id = partition_size * (partition_id - 1)
      partition_end_id = (partition_id == manager_counter) ? self.experiment_size : partition_start_id + partition_size
      query_hash = { "id" => { "$gt" => partition_start_id, "$lte" => partition_end_id } }

      simulations_in_partition = db.count_with_query(self.id, query_hash)
      if simulations_in_partition != partition_end_id - partition_start_id
        Rails.logger.debug("Partition size is #{simulations_in_partition} but should be #{partition_end_id - partition_start_id}")

        simulation_id = find_unsent_simulation_in(partition_start_id, partition_end_id, db)

        return simulation_id if not simulation_id.nil?
      end
    end

    nil
  end

  def is_simulation_ready_to_run(simulation_id, db)
    simulation_doc = db.find_one_with_order(self.id, {"id" => simulation_id})
    Rails.logger.debug("Simulation #{simulation_id} is nil ? #{simulation_doc.nil?}")

    simulation_doc.nil? or simulation_doc["to_sent"]
  end

  def find_unsent_simulation_in(partition_start_id, partition_end_id, db)
    Rails.logger.debug("Finding unsent simulation between #{partition_start_id} and #{partition_end_id}")

    if partition_end_id - partition_start_id < 200 # conquer
      query_hash = { "id" => { "$gt" => partition_start_id, "$lte" => partition_end_id } }
      options_hash = { :fields => { "id" => 1, "_id" => 0 }, :sort => [ [ "id", :asc ] ] }

      simulations_ids = db.find(self.id, query_hash, options_hash).map{|x| x["id"]}
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
      query_hash = { "id" => { "$gt" => partition_start_id, "$lte" => middle_of_partition } }
      size_of_half_partition = db.count_with_query(self.id, query_hash)

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
  
  def prepare_factors_for_instance_generation(parameters, doe_groups)
    counter, index_list, labels, value_list = 1, [], [], [], []

    parameters.each do |param_node|
      counter *= param_node.values.size
      index_list << 0
      labels << param_node.param_id
      value_list << param_node.values
    end

    doe_groups.each do |group_id, doe_group|
      group_values = doe_group.values(File.join(Rails.root, "lib", "designs.R"))
      group_labels = doe_group.labels

      counter *= group_values.size
      index_list << 0

      if ["2k", "fullFactorial"].include?(doe_group.doe_method)
        group_labels.each_with_index do |element, index|
          labels << element
          value_list << group_values[index]
        end
      else
        labels << group_labels
        value_list << group_values
      end

    end
    
    return counter, index_list, labels, value_list
  end
  
  def next_combination_with_shift(index_list, value_list)
    combination = []
    
    index_list.each_with_index do |param_index, i|
      combination << value_list[i][param_index]
    end
    combination.flatten!

    shift = true
    (index_list.size - 1).downto(0) do |k|
      if shift and (index_list[k] == value_list[k].size - 1)
        shift = true
        index_list[k] = 0
      else
        shift = false
        index_list[k] += 1
        break
      end
    end

    combination
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

    columns = ["id", "experiment_id", "is_done", "to_sent", "run_index", "arguments", "values", "sent_at"]
    values  = [instance_id, self.id, false, false, 1, @parametrization_info["labels"].join(","), combination.join(","), Time.now]

    instance_hash = Hash[*columns.zip(values).flatten]
    # Rails.logger.debug("instance_hash: #{instance_hash.inspect}")
    instance = ExperimentInstance.new(instance_hash)
    instance.save

    instance
  end

  # Generate a list of subsequent simulation ids in a random order
  # based on the 'manager_id' attribute and the overall number of registered Experiment Managers
  def create_file_with_ids
    manager_counter = ExperimentManager.count
    id_list = []
    next_simulation_id = Rails.configuration.manager_id

    while next_simulation_id <= self.experiment_size
      id_list << next_simulation_id
      next_simulation_id += manager_counter
    end

    id_list.shuffle!

    File.open(file_with_ids_path, "wb") do |f|
      id_list.each { |num| f << [num].pack("i") }
    end
  end


  def parts_per_progress_bar_slot
    return 1 if self.experiment_size <= 0

    part_width = ExperimentProgressBar::CANVAS_WIDTH / self.experiment_size
    [(ExperimentProgressBar::MINIMUM_SLOT_WIDTH / part_width).ceil, 1].max
  end

  def progress_bar_table
    table_name = "experiment_progress_bar_#{self.id}"
    ExperimentInstanceDb.default_instance.default_connection.collection(table_name)
  end

  add_execution_time_logging :progress_bar_update, :next_simulation_id_with_seek, :naive_partition_based_simulation_hash
end
