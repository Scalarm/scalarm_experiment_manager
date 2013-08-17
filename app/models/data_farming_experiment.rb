require 'json'
require 'csv'
require 'set'
require 'yaml'
require 'experiment_extensions/experiment_extender'
require 'experiment_extensions/data_farming_experiment_progress_bar'
require 'experiment_extensions/data_farming_simulation'
require 'experiment_extensions/simulation_scheduler'

class DataFarmingExperiment < MongoActiveRecord
  include DataFarmingExperimentProgressBar
  include SimulationScheduler
  include ExperimentExtender
  include DataFarmingSimulation

  ID_DELIM = '___'

  def self.collection_name
    'experiments'
  end

  def self.find_by_id(experiment_id)
    if experiment_id.to_i.to_s == experiment_id
      self.find_by('experiment_id', experiment_id.to_i)
    else
      self.find_by('id', experiment_id)
    end
  end

  def self.get_running_experiments
    instances = []

    collection.find({'is_running' => true}).each do |attributes|
      instances << Object.const_get(name).send(:new, attributes)
    end

    instances
  end

  def is_completed
    ExperimentInstance.count_with_query(self.experiment_id) == ExperimentInstance.count_with_query(self.experiment_id, {'is_done' => true})
  end

  def simulation
    Simulation.find_by_id self.simulation_id
  end

  # NOT USED ANY MORE
  ## USE WITH CAUTION !!!
  #def old_fashion_experiment
  #  Experiment.find_by_id(self.experiment_id)
  #end

  def save_and_cache
    #Rails.cache.write("data_farming_experiment_#{self._id}", self, :expires_in => 600.seconds)
    self.save
  end


  def get_statistics
    all  = ExperimentInstance.count_with_query(self.experiment_id)
    done = ExperimentInstance.count_with_query(self.experiment_id, {'is_done' => true})
    sent = ExperimentInstance.count_with_query(self.experiment_id, {'to_sent' => false, 'is_done' => false})

    return all, done, sent
  end

  def argument_names
    parameters.flatten.join(',')
    #params = []
    #
    #self.experiment_input.each do |entity_group|
    #  entity_group['entities'].each do |entity|
    #    entity['parameters'].each do |parameter|
    #        params << parameter_uid(entity_group, entity, parameter)
    #    end
    #  end
    #end
    #
    #params.join(',')
  end

  def range_arguments
    params_with_range = []

    self.experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          if parameter['parametrizationType'] == 'range'
            params_with_range << parameter_uid(entity_group, entity, parameter)
          end
        end
      end
    end

    params_with_range
  end

  def parametrization_of(parameter_uid)
    self.experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          return parameter_uid, parameter['parametrizationType'] if parameter_uid(entity_group, entity, parameter) == parameter_uid
        end
      end
    end

    nil
  end

  def parametrization_values
    parameters = []

    self.experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          parameters += get_parametrization_values(entity_group, entity, parameter)
        end
      end
    end

    parameters.join('|')
  end

  def parameters
    parameters = []

    self.doe_info.each do |doe_group|
      parameters << doe_group[1]
    end

    self.experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          parameters << parameter_uid(entity_group, entity, parameter) unless parameter.include?('in_doe') and parameter['in_doe'] == true
        end
      end
    end

    parameters
  end

  def input_parameter_label_for(uid)
    entity_group_id, entity_id, parameter_id = uid.split(ID_DELIM)

    self.experiment_input.each do |entity_group|
      if entity_group['id'] == entity_group_id
        entity_group['entities'].each do |entity|
          if entity['id'] == entity_id
            entity['parameters'].each do |parameter|
              if parameter['id'] == parameter_id
                return "#{entity_group['label']} - #{entity['label']} - #{parameter['label']}"
              end
            end
          end
        end
      end
    end

    nil
  end

  def value_list(debug = false)
    if self.cached_value_list.nil?
      self.doe_info = apply_doe_methods if self.doe_info.blank? or self.doe_info.first.size == 2
      #Rails.logger.debug("Doe info: #{self.doe_info}")

      value_list = []
      # adding values from Design of Experiment
      self.doe_info.each do |doe_group|
        value_list << doe_group[2]
      end
      # adding the rest of values
      self.experiment_input.each do |entity_group|
        entity_group['entities'].each do |entity|
          entity['parameters'].each do |parameter|
            unless parameter.include?('in_doe') and parameter['in_doe'] == true
              value_list << generate_parameter_values(parameter.merge({'entity_group_id' => entity_group['id'], 'entity_id' => entity['id']}))
            end
          end
        end
      end

      self.cached_value_list = value_list
      self.save_and_cache unless debug
    end

    self.cached_value_list
  end

  def multiply_list(debug = false)
    if self.cached_multiple_list.nil?
      multiply_list = Array.new(value_list.size)

      multiply_list[-1] = 1
      (multiply_list.size - 2).downto(0) do |index|
        multiply_list[index] = multiply_list[index + 1] * value_list[index + 1].size
      end


      self.cached_multiple_list = multiply_list
      self.save_and_cache unless debug
    end

    self.cached_multiple_list
  end

  def apply_doe_methods
    return [] if self.doe_info.blank?

    self.doe_info.map do |doe_name, parameter_list|
      parameter_values = execute_doe_method(doe_name, parameter_list)

      [doe_name, parameter_list, parameter_values]
    end
  end

  def experiment_size(debug = false)
    if self.size.nil?
      self.size = self.value_list.reduce(1){|acc, x| acc * x.size}
      self.save_and_cache unless debug
    end

    self.size
  end

  def create_result_csv_for(moe_name)

    CSV.generate do |csv|
      csv << self.parameters.flatten + [ moe_name ]

      ExperimentInstance.raw_find_by_query(self.experiment_id, { is_done: true }, { fields: %w(values result) }).each do |simulation_doc|
        next if not simulation_doc['result'].has_key?(moe_name)

        values = simulation_doc['values'].split(',').map{|x| '%.4f' % x.to_f}
        csv << values + [ simulation_doc['result'][moe_name] ]
      end
    end

  end

  def moe_names
    moe_name_set = []
    limit = self.experiment_size > 1000 ? self.experiment_size / 2 : self.experiment_size
    ExperimentInstance.raw_find_by_query(self.experiment_id, { is_done: true }, { fields: %w(result), limit: limit }).each do |instance_doc|
      moe_name_set += instance_doc['result'].keys.to_a
    end

    moe_name_set.uniq
  end

  def create_scatter_plot_csv_for(x_axis, y_axis)
    CSV.generate do |csv|
      csv << [ x_axis, y_axis ]

      ExperimentInstance.raw_find_by_query(self.experiment_id, { is_done: true }, { fields: %w(values result arguments) }).each do |simulation_doc|
        simulation_input = Hash[simulation_doc['arguments'].split(',').zip(simulation_doc['values'].split(','))]

        x_axis_value = if simulation_doc['result'].include?(x_axis)
                         # this is a MoE
                         simulation_doc['result'][x_axis]
                       else
                         # this is an input parameter
                         simulation_input[x_axis]
                       end
        y_axis_value = if simulation_doc['result'].include?(y_axis)
                         # this is a MoE
                         simulation_doc['result'][y_axis]
                       else
                         # this is an input parameter
                         simulation_input[y_axis]
                       end

        csv << [ x_axis_value, y_axis_value ]
      end
    end
  end

  def generated_parameter_values_for(parameter_uid)
    simulation_id = 1
    while (instance = ExperimentInstance.find_by_id(self.experiment_id, simulation_id)).nil?
      simulation_id += 1
    end

    #Rails.logger.debug("Parameter UID: #{parameter_uid}")
    #Rails.logger.debug("instance.arguments: #{instance.arguments.split(',')}")
    param_index = instance.arguments.split(',').index(parameter_uid)
    param_value = instance.values.split(',')[param_index]

    find_exp = '^'
    find_exp += "(\\d+\\.\\d+,){#{param_index}}" if param_index > 0
    find_exp = /#{find_exp}#{param_value}/

    query_hash = { 'values' => { '$not' => find_exp } }
    option_hash = { fields: %w(values) }

    param_values = ExperimentInstance.raw_find_by_query(self.experiment_id, query_hash, option_hash).
        map { |x| x['values'].split(',')[param_index] }.uniq + [param_value]

    param_values.map { |x| x.to_f }.uniq.sort
  end

  # return a full experiment input based on partial information given, and using default values for other parameters
  # doe_list = [ [ doe_id, [ param_1, param_2 ] ], ... ]
  def self.prepare_experiment_input(simulation, partial_experiment_input, doe_list = [])
    partial_experiment_input = self.nested_json_to_hash(partial_experiment_input)
    experiment_input = JSON.parse simulation.input_specification

    experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          # check if partial_experiment_input contains information about this parameter
          parameter_uid = self.parameter_uid(entity_group, entity, parameter)
          parameter['with_default_value'] = parameter.include?('value')

          # if there is information then add it to the input
          if partial_experiment_input.include?(parameter_uid)
            partial_experiment_input[parameter_uid].each do |key, value|
              parameter[key] = value
            end
          else
            # otherwise set default values
            parameter['parametrizationType'] = 'value'
            parameter['value'] = parameter['value'] || parameter['min']
          end
          # check if this parameter is included in DoE and mark it accordingly
          parameter['in_doe'] = false
          doe_list.each do |doe_id, parameter_list|
            #Rails.logger.debug("Parameter: #{parameter_uid} --- Parameter list: #{parameter_list.join(',')}")
            if parameter_list.include?(parameter_uid)
              parameter['in_doe'] = true
              break
            end
          end

        end
      end
    end

  end

  def create_result_csv
    moes = self.moe_names

    CSV.generate do |csv|
      csv << self.parameters.flatten + moes

      self.find_simulation_docs_by({ is_done: true }, { fields: %w(values result) }).each do |simulation_doc|
        values = simulation_doc['values'].split(',').map{|x| '%.4f' % x.to_f}
        moe_values = moes.reduce([]){ |tab, moe_name| tab << simulation_doc['result'][moe_name] || '' }

        csv << values + moe_values
      end
    end
  end

  def destroy
    # TODO TMP due to problem with routing in PLGCloud
    information_service = InformationService.new({'information_service_url' => 'localhost:11300'})
    @storage_manager_url = information_service.get_storage_managers.sample
    # destroy all binary files stored for this experiments
    sm_uuid = SecureRandom.uuid
    temp_password = SimulationManagerTempPassword.create_new_password_for(sm_uuid)
    # TODO TMP due to problem with routing in PLGCloud
    config = {'storage_manager' => { 'address' => 'localhost:20000', 'user' => sm_uuid, 'pass' => temp_password.password} }
    Rails.logger.debug("Destroy config = #{config}")

    sm_proxy = StorageManagerProxy.new(config)

    begin
      #1.upto(self.experiment_size).each do |simulation_id|
        success = sm_proxy.delete_experiment_output(self.experiment_id, self.experiment_size)
        Rails.logger.debug("Deletion of experiment output #{experiment_size} completed successfully ? #{success}")
      #end
    rescue Exception => e
      Rails.logger.debug("Data farming experiment destroy error - #{e}")
    end

    temp_password.destroy

    # drop simulation table
    @@db[ExperimentInstanceDb.collection_name(self.experiment_id)].drop
    # drop progress bar object
    self.progress_bar_table.drop
    # drop object from relational database
    #experiment = Experiment.find_by_id(self.experiment_id)
    #experiment.destroy if not experiment.nil?
    # self-drop
    @@db['experiments_info'].remove({ experiment_id: self.experiment_id })
    DataFarmingExperiment.destroy({ experiment_id: self.experiment_id })
  end

  def result_names
    moe_name_set = Set.new
    result_limit = self.experiment_size < 5000 ? self.experiment_size : (self.experiment_size / 2)

    ExperimentInstance.raw_find_by_query(self.experiment_id, {is_done: true}, {fields: 'result', limit: result_limit}).each do |simulation_doc|
      moe_name_set += simulation_doc['result'].keys
    end

    moe_name_set.empty? ? nil : moe_name_set.to_a
  end

  def completed_simulations_count_for(secs)
    query = { 'is_done' => true, 'done_at' => { '$gte' => (Time.now - secs)} }

    ExperimentInstance.count_with_query(self.experiment_id, query)
  end

  def clear_cached_data
    self.cached_value_list = nil
    self.cached_multiple_list = nil
    self.size = nil
    self.labels = nil

    #self.save_and_cache
  end

  def get_parameter_doc(parameter_uid)
    entity_group_id, entity_id, parameter_id = parameter_uid.split(ID_DELIM)
    self.experiment_input.each do |entity_group|

      if entity_group['id'] == entity_group_id

        entity_group['entities'].each do |entity|

          if entity['id'] == entity_id

            entity['parameters'].each do |parameter|

              if parameter['id'] == parameter_id

                return parameter

              end

            end

          end

        end

      end

    end
  end

  # returns a list of generated values for the given parameter_uid
  # it takes into account 'value_list' and 'value_list_extension'
  def parameter_values_for(parameter_uid)
    values = []

  #  if this parameter is used in DoE => get all values from doe_info
    if get_parameter_doc(parameter_uid)['in_doe']

      self.doe_info.each do |method, list_of_parameters, doe_values|
        unless (param_index = list_of_parameters.index(parameter_uid)).nil?
          doe_values.each do |configuration|
            values << configuration[param_index]
          end
          values.uniq!
        end
      end

    else
  #  if not used in DoE => get values from 'value_list' and 'value_list_extension'
      param_index = self.parameters.index(parameter_uid)
      values += value_list[param_index]

      unless self.value_list_extension.nil?
        self.value_list_extension.each do |param_name, list_of_additional_values|
          if param_name == parameter_uid
            values += list_of_additional_values
          end
        end
      end

    end

    values
  end

  private

  def self.nested_json_to_hash(nested_json)
    hash_counterpart = Hash.new
    nested_json.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          parameter_uid = "#{entity_group['id']}#{DataFarmingExperiment::ID_DELIM}#{entity['id']}#{DataFarmingExperiment::ID_DELIM}#{parameter['id']}"
          hash_counterpart[parameter_uid] = parameter
        end
      end
    end

    hash_counterpart
  end

  def parameter_uid(entity_group, entity, parameter)
    DataFarmingExperiment.parameter_uid(entity_group, entity, parameter)
  end

  def self.parameter_uid(entity_group, entity, parameter)
    entity_group_id = entity_group.include?('id') ? entity_group['id'] : entity_group
    entity_id = entity.include?('id') ? entity['id'] : entity
    parameter_id = parameter.include?('id') ? parameter['id'] : parameter

    "#{entity_group_id}#{ID_DELIM}#{entity_id}#{ID_DELIM}#{parameter_id}"
  end

  def get_parametrization_values(entity_group, entity, parameter)
    parametrization_values = []
    parameter_uid = parameter_uid(entity_group, entity, parameter)

    if parameter["parametrizationType"] == "value"
      parametrization_values << "#{parameter_uid}_value=#{parameter["value"]}"
    elsif parameter["parametrizationType"] == "range"
      parametrization_values << "#{parameter_uid}_min=#{parameter["min"]}"
      parametrization_values << "#{parameter_uid}_max=#{parameter["max"]}"
      parametrization_values << "#{parameter_uid}_step=#{parameter["step"]}"
    elsif parameter["parametrizationType"] == "gauss"
      parametrization_values << "#{parameter_uid}_mean_value=#{parameter["mean"]}"
      parametrization_values << "#{parameter_uid}_variance_value=#{parameter["variance"]}"
    elsif parameter["parametrizationType"] == "uniform"
      parametrization_values << "#{parameter_uid}_min_value=#{parameter["min"]}"
      parametrization_values << "#{parameter_uid}_max_value=#{parameter["max"]}"
    end

    parametrization_values
  end

  def generate_parameter_values(parameter)
    parameter_uid = parameter_uid({'id' => parameter['entity_group_id']}, {'id' => parameter['entity_id']}, parameter)

    self.doe_info.each do |doe_element|
      doe_id, doe_parameters = doe_element
      if doe_parameters.include?(parameter_uid)
        #Rails.logger.debug("Parameter #{parameter_uid} is on DoE list")
      end
    end

    parameter_values = []

    if parameter['parametrizationType'] == 'value'
      parameter_values << parameter['value'].to_f
    elsif parameter['parametrizationType'] == 'range'
      step = parameter['step'].to_f
      raise "Step can't be zero" if step == 0.0

      value = parameter['min'].to_f
      while value < parameter['max'].to_f
        parameter_values << value.round(3)
        value += step.round(3)
      end
    elsif parameter['parametrizationType'] == 'gauss'
      r_interpreter = Rails.configuration.eusas_rinruby
      #Rails.logger.debug("Mean: #{parameter['mean'].to_f}")
      #Rails.logger.debug("Variance: #{parameter['variance'].to_f}")
      r_interpreter.eval("x <- rnorm(1, #{parameter['mean'].to_f}, #{parameter['variance'].to_f})")
      parameter_values << ('%.3f' % r_interpreter.pull('x').to_f).to_f
    elsif parameter['parametrizationType'] == 'uniform'
      r_interpreter = Rails.configuration.eusas_rinruby
      r_interpreter.eval("x <- runif(1, #{parameter['min'].to_f}, #{parameter['max'].to_f})")
      parameter_values << ('%.3f' % r_interpreter.pull('x').to_f).to_f
    end

    unless self.value_list_extension.nil?
      self.value_list_extension.each do |param_name, list_of_additional_values|
        if param_name == parameter_uid
          parameter_values += list_of_additional_values
        end
      end
    end

    parameter_values
  end

  def execute_doe_method(doe_method_name, parameters_for_doe)
    case doe_method_name
      when '2k'
        values = parameters_for_doe.reduce([]) { |sum, parameter_uid|
          parameter = get_parameter_doc(parameter_uid)
          sum << [ parameter['min'].to_f, parameter['max'].to_f ]
        }

        if values.size > 1
          values = values[1..-1].reduce(values.first){|acc,values| acc.product values}.map{|x| x.flatten}
        else
          values = values.first.map{|x| [ x ]}
        end

        values

      when 'fullFactorial'
        values = parameters_for_doe.reduce([]) { |sum, parameter_uid|
          parameter = get_parameter_doc(parameter_uid)
          sum << (parameter['min'].to_f..parameter['max'].to_f).step(parameter['step'].to_f).to_a
        }

        if values.size > 1
          values = values[1..-1].reduce(values.first) { |acc, values| acc.product values }.map { |x| x.flatten }
        else
          values = values.first.map { |x| [x] }
        end

        values

      when *%w(latinHypercube fractionalFactorial nolhDesign)
        design_file_path = File.join(Rails.root, 'lib', 'designs.R')
        Rails.logger.info("arg <- #{data_frame(parameters_for_doe)} source('#{design_file_path}') design <- #{doe_method_name}(arg) design <- data.matrix(design)")
        Rails.configuration.eusas_rinruby.eval("arg <- #{data_frame(parameters_for_doe)}
            source('#{design_file_path}')
            design <- #{doe_method_name}(arg)
            design <- data.matrix(design)")

        values = Rails.configuration.eusas_rinruby.design.to_a
        values = values.map{|list| list.map{|num| num.round(5)}}
        Rails.logger.debug("Design: #{values}")

        values
    end
  end

  def data_frame(parameter_list)
    data_frame_list = parameter_list.map do |parameter_uid|
      parameter = get_parameter_doc(parameter_uid)
      "#{parameter_uid}=c(#{parameter['min']}, #{parameter['max']}, #{parameter['step']})"
    end

    "data.frame(#{data_frame_list.join(',')})"
  end




end