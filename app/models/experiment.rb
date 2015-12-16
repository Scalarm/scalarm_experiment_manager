require 'json'
require 'csv'
require 'set'
require 'yaml'

# Attributes:
#_id: id
#experiment_id: ObjectId - same as _id
#name: user specified name
#description: (optional) a longer description of the experiment
#is_running: bool
#replication_level: how many times each configuration should be executed
#simulation_id: id of a simulation which is executed during the experiment
#user_id: ObjectId
#time_constraint_in_sec: integer - threshold for simulation execution
#experiment_input: JSON structure defining parametrization of the used simulation
# - basically it is an extended version of a simulation input structure; extended with information about parametrization of each parameter
#   -  "parametrizationType" : "value",      "in_doe" : false
#doe_info: information about used DoE methods - an array of triples, [ doe_method_id, array_of_parameter_ids, array_of_lists_with_values_for_each_simulation ]
#scheduling_policy: string -
#run_counter: integer - how many times each simulation should be executed
#labels: (dynamic) string - concatenated list of parameter ids
#“cached_value_list”: a utilization array of values of each parameter
#“start_at”: when the experiment has been created
#“end_at”: when the user clicked “Stop”
#“size”: (cache) the number of all simulations
#“cached_multiple_list”: (cache) a list of integers generated by multiplying sizes of subsequent parameter values

require 'scalarm/database/model/experiment'

class Experiment < Scalarm::Database::Model::Experiment
  require 'experiment_extensions/experiment_extender'
  require 'experiment_extensions/experiment_progress_bar'
  require 'experiment_extensions/simulation_run_module'
  require 'experiment_extensions/simulation_scheduler'
  require 'scalarm/service_core/parameter_validation'

  include ExperimentProgressBar
  include SimulationScheduler
  include ExperimentExtender
  include SimulationRunModule
  include Scalarm::ServiceCore::ParameterValidation

  # attr_joins are overriden to get proper classes (not basic models)
  attr_join :simulation, Simulation
  attr_join :user, ScalarmUser

  def self.to_a
    super.map { |e| e.auto_convert }
  end

  def simulation_runs
    SimulationRunFactory.for_experiment(id)
  end

  def save_and_cache
    self.save
  end

  def stop!
    self.is_running = false
    self.end_at = Time.now
    destroy_temp_passwords!
    self.save_and_cache
  end

  def destroy_temp_passwords!
    simulation_manager_temp_passwords.each &:destroy
  end

  def share_with_anonymous
    anonymous_user = ScalarmUser.get_anonymous_user
    add_to_shared(anonymous_user.id) if anonymous_user and
        (shared_with.nil? or not shared_with.include?(anonymous_user.id))
  end

  def add_to_shared(user_id)
    sharing_list = (self.shared_with or [])
    sharing_list << user_id

    self.shared_with = sharing_list
  end

  def has_simulations_to_run?
    all, sent, done = get_statistics
    experiment_size > (sent+done)
  end

  # Should, in this moment, more computations for this experiment should be made?
  def end?
    (self.is_running == false) or completed?
  end

  # Are all scheduled simulations done?
  def completed?
    (self.experiment_size == self.count_done_simulations)
  end

  def get_statistics
    all = simulation_runs.count
    sent = simulation_runs.where(to_sent: false, is_done: false).count
    done = simulation_runs.where(is_done: true).count

    return all, sent, done
  end

  def count_all_generated_simulations
    get_statistics[0]
  end

  def count_sent_simulations
    get_statistics[1]
  end

  def count_done_simulations
    get_statistics[2]
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

  def parameters_with_multiple_values
    result = self.range_arguments

    self.doe_info.each do |triple|
      result += triple[1]
    end

    result
  end

  # @return [Array<String>] Array of parameter ids in proper order
  # NOTICE: value of this function should be cached
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
    split_uid = uid.split(ID_DELIM)
    entity_group_id, entity_id, parameter_id = split_uid[-3], split_uid[-2], split_uid[-1]

    if parameter_id.blank? and (not entity_id.blank?)
      parameter_id = entity_id
      entity_id = nil
    end

    if parameter_id.blank? and (not entity_group_id.blank?)
      parameter_id = entity_group_id
      entity_group_id = nil
    end

    self.experiment_input.each do |entity_group|
      if entity_group['id'] == entity_group_id || (entity_group['id'].blank? and entity_group_id.blank?)
        entity_group['entities'].each do |entity|
          if entity['id'] == entity_id || (entity['id'].blank? and entity_id.blank?)
            entity['parameters'].each do |parameter|
              if parameter['id'] == parameter_id
                return [entity_group['label'], entity['label'], parameter['label']].compact.join(" - ")
              end
            end
          end
        end
      end
    end

    nil
  end

  def self.output_parameter_label_for(moe_name)
    label = moe_name.split(/([[:upper:]][[:lower:]]+)/).delete_if(&:empty?).join(" ")

    label.split(' ').map { |x| x[0].capitalize + x[1..-1] }.join(' ').gsub('_', ' ')
  end


  def value_list(debug = false)
    #Rails.logger.debug("Value list starting --- #{self.doe_info.inspect} --- #{self.doe_info.blank?} --- #{self.doe_info.first}")
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
              #Rails.logger.debug("value_list begin - #{parameter['id']}")
              value_list << generate_parameter_values(parameter.merge({'entity_group_id' => entity_group['id'], 'entity_id' => entity['id']}))
              #Rails.logger.debug("value_list end - #{parameter['id']}")
            end
          end
        end
      end

      self.cached_value_list = value_list
      self.save_and_cache if (not debug) and (not self.debug.nil?) and (not self.debug)
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
      self.save_and_cache if (not debug) and (not self.debug.nil?) and (not self.debug)
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

  def replication_level
    super or 1
  end

  def experiment_size(debug = false)
    if self.size.nil?
      self.size = 0
      list_of_values = value_list(debug)
      max_size = list_of_values.reduce(1) { |acc, x| acc * x.size } * replication_level

      if parameters_constraints.blank?
        self.size = max_size
      else
        self.excluded_indexes = []

        1.upto(max_size).each do |i|
          simulation_run = generate_simulation_for(i)
          if simulation_run.meet_constraints?(parameters_constraints)
            self.size += 1
          else
            self.excluded_indexes << i
          end
        end
      end
    end

    self.size
  end

  def extend_progress_bar
    self.create_progress_bar_table.drop
    self.insert_initial_bar
    # to not draw gray bar if the last change was made < 30 sec -> method Experiment_progress_bar.update_all_bars
    Rails.cache.delete_matched(/progress_bar_#{self.id}_\d+/)
    # Rails.logger.debug("Updating all progress bars --- #{Time.now - @experiment.start_at}")
    Thread.start { self.update_all_bars }
  end

  def experiment_size=(new_size)
    @attributes['experiment_size'] = new_size
    self.size = new_size
  end

  def create_result_csv_for(moe_name)

    CSV.generate do |csv|
      csv << self.parameters.flatten + [moe_name]

      simulation_runs.where({is_done: true, is_error: {'$exists' => false}}).each do |simulation_run|
        next if not simulation_run.result.has_key?(moe_name)

        values = simulation_run.values.split(',')
        #Rails.logger.debug("Values: #{values.inspect}")
        csv << values + [simulation_run.result[moe_name]]
      end
    end

  end

  def moe_names
    moe_name_set = []
    limit = self.experiment_size > 1000 ? self.experiment_size / 2 : self.experiment_size
    simulation_runs.where({is_done: true}, {fields: %w(result), limit: limit}).each do |simulation_run|
      moe_name_set += simulation_run.result.keys.to_a
    end

    moe_name_set.uniq
  end

  def create_scatter_plot_csv_for(x_axis, y_axis)
    CSV.generate do |csv|
      csv << [x_axis, y_axis, 'simulation_run_ind']

      simulation_runs.where({is_done: true, is_error: {'$exists' => false}}).each do |simulation_run|
        simulation_run_ind = simulation_run.index.to_s

        x_axis_value = if simulation_run.result.include?(x_axis)
                         # this is a MoE
                         simulation_run.result[x_axis]
                       else
                         # this is an input parameter
                         simulation_run.input_parameters[x_axis]
                       end
        y_axis_value = if simulation_run.result.include?(y_axis)
                         # this is a MoE
                         simulation_run.result[y_axis]
                       else
                         # this is an input parameter
                         simulation_run.input_parameters[y_axis]
                       end

        csv << [x_axis_value, y_axis_value, simulation_run_ind]
      end
    end
  end

  def generated_parameter_values_for(parameter_uid)
    simulation_id = 1
    while (instance = simulation_runs.where(index: simulation_id).nil?)
      simulation_id += 1
    end

    #Rails.logger.debug("Parameter UID: #{parameter_uid}")
    #Rails.logger.debug("instance.arguments: #{instance.arguments.split(',')}")
    param_index = instance.arguments.split(',').index(parameter_uid)
    param_value = instance.values.split(',')[param_index]

    find_exp = '^'
    find_exp += "(\\d+\\.\\d+,){#{param_index}}" if param_index > 0
    find_exp = /#{find_exp}#{param_value}/

    param_values = simulation_runs.where({values: {'$not' => find_exp}}, {fields: %w(values)}).
        map { |x| x.values.split(',')[param_index] }.uniq + [param_value]

    param_values.map { |x| x.to_f }.uniq.sort
  end

  ## return a full experiment input based on partial information given, and using default values for other parameters
  ## doe_list = [ [ doe_id, [ param_1, param_2 ] ], ... ]
  def self.prepare_experiment_input(simulation, partial_experiment_input, doe_list = [])
    partial_experiment_input = self.nested_json_to_hash(partial_experiment_input)
    experiment_input = simulation.input_specification

    experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          # check if partial_experiment_input contains information about this parameter
          parameter_uid = self.parameter_uid(entity_group, entity, parameter)
          parameter['with_default_value'] = parameter.include?('value')

          # if there is information then add it to the input
          if partial_experiment_input.include?(parameter_uid)
            partial_experiment_input[parameter_uid].each do |key, value|
              if partial_experiment_input[parameter_uid]['parametrizationType'] == 'custom' and key == 'custom_values'
                parameter[key] = value.split("\n")
              else
                parameter[key] = value
              end
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

  def create_result_csv(with_index=false, with_params=true, with_moes=true, error_description = false, additional_query=nil)
    moes = self.moe_names
    additional_query ||= {}

    CSV.generate do |csv|
      header = []
      header += ['simulation_index'] if with_index
      header += self.parameters.flatten if with_params
      header += moes if with_moes
      header += ['status'] if error_description
      header += ['error_reason'] if error_description
      csv << header
      query_fields = {_id: 0}
      query_fields[:index] = 1 if with_index
      query_fields[:values] = 1 if with_params
      query_fields[:result] = 1 if with_moes
      simulation_runs.where(
          {is_done: true}.merge(additional_query),
          {fields: query_fields}
      ).each do |simulation_run|
        if error_description
          line = []
          line += [simulation_run.index] if with_index
          line += simulation_run.values.split(',') if with_params
          # getting values of results in a specific order
          line += moes.map { |moe_name| simulation_run.result[moe_name] || '' } if with_moes
          line += simulation_run.is_error ? ['error'] : ['ok']
          line += simulation_run.is_error ? [simulation_run.error_reason] : [nil]
          csv << line
        elsif !simulation_run.is_error
          line = []
          line += [simulation_run.index] if with_index
          line += simulation_run.values.split(',') if with_params
          # getting values of results in a specific order
          line += moes.map { |moe_name| simulation_run.result[moe_name] || '' } if with_moes
          csv << line
        end

      end
    end
  end

  # TODO: use token authentication
  def destroy
    # TODO TMP due to problem with routing in PLGCloud
    information_service = InformationService.instance
    @storage_manager_url = information_service.get_list_of('storage').sample

    unless @storage_manager_url
      # destroy all binary files stored for this experiments
      sm_uuid = SecureRandom.uuid
      temp_password = SimulationManagerTempPassword.create_new_password_for(sm_uuid, self.experiment_id)
      begin
        config = {'storage_manager' => {'address' => @storage_manager_url, 'user' => sm_uuid, 'pass' => temp_password.password}}
        Rails.logger.debug("Destroy config = #{config}")

        sm_proxy = StorageManagerProxy.new(config)
        begin
          success = sm_proxy.delete_experiment_output(self.experiment_id, self.experiment_size)
          Rails.logger.debug("Deletion of experiment output #{experiment_size} completed successfully ? #{success}")
        rescue Exception => e
          Rails.logger.debug("Data farming experiment destroy error - #{e}")
        end
      ensure
        temp_password.destroy
      end
    end

    # drop simulation table
    simulation_runs.collection.drop
    # drop progress bar object
    self.progress_bar_table.drop
    # self-drop
    @@db['experiments_info'].remove({_id: self.id})
    Experiment.destroy({_id: self.id})
  end

  def result_names
    moe_name_set = Set.new
    result_limit = self.experiment_size < 5000 ? self.experiment_size : (self.experiment_size / 2)

    query_opts = {fields: {_id: 0, result: 1, is_error: 1}, limit: result_limit}
    simulation_runs.where({is_done: true}, query_opts).each do |simulation_run|
      unless simulation_run.is_error == true
        moe_name_set += simulation_run.result.keys
      end
    end

    moe_name_set.empty? ? nil : moe_name_set.to_a
  end

  def clear_cached_data
    self.cached_value_list = nil
    self.cached_multiple_list = nil
    self.size = nil
    self.labels = nil

    self.save_and_cache
  end

  # Returns parameter doc (Hash) or nil if not found
  def get_parameter_doc(parameter_uid)
    split_uid = parameter_uid.split(ID_DELIM)
    entity_group_id, entity_id, parameter_id = split_uid[-3], split_uid[-2], split_uid[-1]

    if parameter_id.blank? and (not entity_id.blank?)
      parameter_id = entity_id
      entity_id = nil
    end

    if parameter_id.blank? and (not entity_group_id.blank?)
      parameter_id = entity_group_id
      entity_group_id = nil
    end

    self.experiment_input.each do |entity_group|
      if entity_group['id'] == entity_group_id || (entity_group_id.blank? and entity_group['id'].blank?)
        entity_group['entities'].each do |entity|
          if entity['id'] == entity_id || (entity_id.blank? and entity['id'].blank?)
            entity['parameters'].each do |parameter|
              if parameter['id'] == parameter_id
                return parameter
              end
            end
          end
        end
      end
    end
    nil
  end

  ## returns a list of generated values for the given parameter_uid
  ## it takes into account 'value_list' and 'value_list_extension'
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

    # TODO - probably hack critical!!!
    values.uniq
  end

  def csv_parameter_ids
    self.doe_info[0][1]
  end

  def csv_imported?
    self.doe_info and not self.doe_info.empty? and self.doe_info[0][0] == 'csv_import'
  end

  # parameters - Hash of input parameters
  # NOTE: all parameters must match (every single parameter must be specified)
  # returns Hash with result
  # TODO: handle results with errors
  def get_result_for(simulation_parameters)
    # TODO: check if SimulationRun.arguments is always the same as Experiment.parameters
    values = self.parameters.flatten.collect do |p|
      simulation_parameters[p.to_s] || simulation_parameters[p.to_sym]
    end

    values = values.collect(&:to_s).join(',')

    sim_run = self.simulation_runs.where(
        {is_done: true, values: values},
        {fields: {_id: 0, result: 1}}
    ).first

    sim_run and sim_run.result
  end


  # Narrow the type of experiment
  # Return object with same data, but narrowed class
  def auto_convert
    class_name = ExperimentFactory.resolve_type(self)
    self.convert_to(class_name.constantize)
  end

  private

  def self.nested_json_to_hash(nested_json)
    hash_counterpart = Hash.new

    nested_json.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          parameter_uid = parameter_uid(entity_group, entity, parameter)
          hash_counterpart[parameter_uid] = parameter
        end
      end
    end

    hash_counterpart
  end

  def generate_parameter_values(parameter)
    parameter_uid = parameter_uid({'id' => parameter['entity_group_id']}, {'id' => parameter['entity_id']}, parameter)

    #self.doe_info.each do |doe_element|
    #  doe_id, doe_parameters = doe_element
    #  if doe_parameters.include?(parameter_uid)
    #Rails.logger.debug("Parameter #{parameter_uid} is on DoE list")
    #end
    #end

    parameter_values = []

    case parameter['parametrizationType']

      when 'value'
        # checking parameters for alpha-numeric characters, '_', '-' and '.'
        validate_parameter_value(parameter['label'], parameter['value'])

        parameter_values << parameter['value']

      when 'range'
        # checking parameters for alpha-numeric characters, '_', '-' and '.'
        ['type', 'step', 'min', 'max'].each do |input_type|
          value_of_input = parameter[input_type]
          validate_parameter_value(parameter['label'], value_of_input)
        end

        step = if parameter['type'] == 'float'
                 parameter['step'].to_f
               elsif parameter['type'] == 'integer'
                 parameter['step'].to_i
               end
        raise "Step can't be zero" if step.to_f == 0.0

        value = parameter['min'].to_f
        while value <= parameter['max'].to_f
          parameter_values << value.round(3)
          value += step.round(3)
        end

      when 'gauss'
        # checking parameters for alpha-numeric characters, '_', '-' and '.'
        ['mean', 'variance'].each do |input_type|
          value_of_input = parameter[input_type]
          validate_parameter_value(parameter['label'], value_of_input)
        end

        r_interpreter = Rails.configuration.r_interpreter
        r_interpreter.eval("x <- rnorm(1, #{parameter['mean'].to_f}, #{parameter['variance'].to_f})")
        parameter_values << ('%.3f' % r_interpreter.pull('x').to_f)

      when 'uniform'
        # checking parameters for alpha-numeric characters, '_', '-' and '.'
        ['min', 'max'].each do |input_type|
          value_of_input = parameter[input_type]
          validate_parameter_value(parameter['label'], value_of_input)
        end

        r_interpreter = Rails.configuration.r_interpreter
        r_interpreter.eval("x <- runif(1, #{parameter['min'].to_f}, #{parameter['max'].to_f})")
        parameter_values << ('%.3f' % r_interpreter.pull('x').to_f)

      when 'custom'
        parameter_values.concat(parameter['custom_values'])

    end

    Rails.logger.debug("Parameter type: #{parameter['type']} --- #{parameter_values.inspect}")

    case parameter['type']

      when 'integer'
        parameter_values.map!(&:to_i)

      when 'float'
        parameter_values.map!(&:to_f)

      when 'string'
        parameter_values.map!(&:to_s)

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

  def validate_parameter_value(name_of_input_parameter, value_of_input)
    if /\A(\w|-|\.)+\z/.match(value_of_input).nil?
      type_of_error = value_of_input.empty? ? 'Empty' : 'Wrong'
      raise ValidationError.new(name_of_input_parameter, value_of_input, "#{type_of_error} value for parameter given")
    end
  end

  def execute_doe_method(doe_method_name, parameters_for_doe)
    Rails.logger.debug("Execute doe method: #{doe_method_name} -- #{parameters_for_doe.inspect}")

    case doe_method_name
      when '2k'
        values = parameters_for_doe.reduce([]) { |sum, parameter_uid|
          parameter = get_parameter_doc(parameter_uid)
          sum << [parameter['min'].to_f, parameter['max'].to_f]
        }

        if values.size > 1
          values = values[1..-1].reduce(values.first) { |acc, values| acc.product values }.map { |x| x.flatten }
        else
          values = values.first.map { |x| [x] }
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

      when '2k-1'
        if parameters_for_doe.size < 3
          raise StandardError.new(I18n.t('experiments.errors.too_few_parameters', count: 2))
        else
          values = parameters_for_doe.reduce([]) { |sum, parameter_uid|
            parameter = get_parameter_doc(parameter_uid)
            sum << [{level: -1, value: parameter['min'].to_f}, {level: 1, value: parameter['max'].to_f}]
          }

          if values.size > 1
            values = values[1..-1].reduce(values.first) { |acc, values| acc.product values }.map { |x| x.flatten }
          else
            values = values.first.map { |x| [x] }
          end

          values = values.select { |array| array[0..-2].reduce(1) { |acc, item| acc*item[:level] } == array[-1][:level] }
          values = values.map { |array| array.map { |item| item[:value] } }

          values
        end

      when '2k-2'
        if parameters_for_doe.size < 5
          raise StandardError.new(I18n.t('experiments.errors.too_few_parameters', count: 4))
        else
          values = parameters_for_doe.reduce([]) { |sum, parameter_uid|
            parameter = get_parameter_doc(parameter_uid)
            sum << [{level: -1, value: parameter['min'].to_f}, {level: 1, value: parameter['max'].to_f}]
          }

          if values.size > 1
            values = values[1..-1].reduce(values.first) { |acc, values| acc.product values }.map { |x| x.flatten }
          else
            values = values.first.map { |x| [x] }
          end

          values = values.select { |array| array[0..-4].reduce(1) { |acc, item| acc*item[:level] } == array[-2][:level] }
          values = values.select { |array| array[1..-3].reduce(1) { |acc, item| acc*item[:level] } == array[-1][:level] }
          values = values.map { |array| array.map { |item| item[:value] } }

          values
        end

      when *%w(latinHypercube fractionalFactorial nolhDesign)
        if parameters_for_doe.size < 2
          raise StandardError.new(I18n.t('experiments.errors.too_few_parameters', count: 1))
        else
          design_file_path = File.join(Rails.root, 'public', 'designs.R')
          Rails.logger.info("" "arg <- #{data_frame(parameters_for_doe)} source('#{design_file_path}')
                               design <- #{doe_method_name}(arg) design <- data.matrix(design)" "")
          Rails.configuration.r_interpreter.eval("arg <- #{data_frame(parameters_for_doe)}
              source('#{design_file_path}')
              design <- #{doe_method_name}(arg)
              design <- data.matrix(design)")

          values = Rails.configuration.r_interpreter.design.to_a
          values = values.map { |list| list.map { |num| num.round(5) } }
          #Rails.logger.debug("Design: #{values}")

          values
        end
    end
  end

  def data_frame(parameter_list)
    data_frame_list = parameter_list.map do |parameter_uid|
      parameter = get_parameter_doc(parameter_uid)
      # checking parameters for alpha-numeric characters, '_', '-' and '.'
      [parameter_uid, parameter['min'], parameter['max'], parameter['step']].each do |some_value|
        if /\A((\w)|(-)|(\.))+\z/.match(some_value).nil?
          raise SecurityError.new("Insecure parameter given - #{parameter.to_s}")
        end
      end
      "#{parameter_uid}=c(#{parameter['min']}, #{parameter['max']}, #{parameter['step']})"
    end

    "data.frame(#{data_frame_list.join(',')})"
  end


end
