require 'json'
require 'csv'
require 'set'
require 'yaml'
require 'experiment_extensions/experiment_extender'
require 'experiment_extensions/experiment_progress_bar'
require 'experiment_extensions/simulation_run'
require 'experiment_extensions/simulation_scheduler'

# Attributes:
#_id: id
#experiment_id: ObjectId - same as _id
#name: user specified name
#description: (optional) a longer description of the experiment
#is_running: bool
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

class Experiment < MongoActiveRecord
  include ExperimentProgressBar
  include SimulationScheduler
  include ExperimentExtender
  include SimulationRunModule

  ID_DELIM = '___'

  attr_join :simulation, Simulation
  attr_join :user, ScalarmUser

  def simulation_runs
    SimulationRun.for_experiment(id)
  end

  def self.collection_name
    'experiments'
  end

  def initialize(attributes)
    super(attributes)
  end

  def simulation
    Simulation.find_by_id self.simulation_id
  end

  def save_and_cache
    self.save
  end

  def save
    share_with_anonymous
    super
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

  def end?
    (self.is_running == false) or
        (self.experiment_size == self.count_done_simulations)
  end

  def get_statistics
    all  = simulation_runs.count
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
                return [ entity_group['label'], entity['label'], parameter['label'] ].compact.join(" - ")
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

    label.split(' ').map{|x| x[0].capitalize + x[1..-1]}.join(' ').gsub('_', ' ')
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

  def experiment_size(debug = false)
    if self.size.nil?
      self.size = 0
      list_of_values = value_list(debug)
      max_size = list_of_values.reduce(1){|acc, x| acc * x.size}

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

  def experiment_size=(new_size)
    @attributes['experiment_size'] = new_size
    self.size = new_size
  end

  def create_result_csv_for(moe_name)

    CSV.generate do |csv|
      csv << self.parameters.flatten + [ moe_name ]

      simulation_runs.where({ is_done: true }, { fields: %w(values result) }).each do |simulation_run|
        next if not simulation_run.result.has_key?(moe_name)

        values = simulation_run.values.split(',').map{|x| '%.4f' % x.to_f}
        csv << values + [ simulation_run.result[moe_name] ]
      end
    end

  end

  def moe_names
    moe_name_set = []
    limit = self.experiment_size > 1000 ? self.experiment_size / 2 : self.experiment_size
    simulation_runs.where({ is_done: true }, { fields: %w(result), limit: limit }).each do |simulation_run|
      moe_name_set += simulation_run.result.keys.to_a
    end

    moe_name_set.uniq
  end

  def create_scatter_plot_csv_for(x_axis, y_axis)
    CSV.generate do |csv|
      csv << [ x_axis, y_axis ]

      simulation_runs.where({ is_done: true }, { fields: %w(values result arguments) }).each do |simulation_run|
        simulation_input = Hash[simulation_run.arguments.split(',').zip(simulation_run.values.split(','))]

        x_axis_value = if simulation_run.result.include?(x_axis)
                         # this is a MoE
                         simulation_run.result[x_axis]
                       else
                         # this is an input parameter
                         simulation_input[x_axis]
                       end
        y_axis_value = if simulation_run.result.include?(y_axis)
                         # this is a MoE
                         simulation_run.result[y_axis]
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

    param_values = simulation_runs.where({ values: { '$not' => find_exp } }, { fields: %w(values) }).
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

  def create_result_csv
  	moes = self.moe_names

    CSV.generate do |csv|
      csv << self.parameters.flatten + moes

      simulation_runs.where({ is_done: true }, { fields: { _id: 0, values: 1, result: 1 } }).each do |simulation_run|
        values = simulation_run.values.split(',').map{|x| '%.4f' % x.to_f}
        # getting values of results in a specific order
        moe_values = moes.map{|moe_name| simulation_run.result[moe_name] || '' }

        csv << values + moe_values
      end
    end
  end

  def destroy
    # TODO TMP due to problem with routing in PLGCloud
    config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
    information_service = InformationService.new
    @storage_manager_url = information_service.get_list_of('storage').sample

    unless @storage_manager_url
      # destroy all binary files stored for this experiments
      sm_uuid = SecureRandom.uuid
      temp_password = SimulationManagerTempPassword.create_new_password_for(sm_uuid, self.experiment_id)
      config = {'storage_manager' => { 'address' => @storage_manager_url, 'user' => sm_uuid, 'pass' => temp_password.password} }
      Rails.logger.debug("Destroy config = #{config}")

      sm_proxy = StorageManagerProxy.new(config)
      begin
        success = sm_proxy.delete_experiment_output(self.experiment_id, self.experiment_size)
        Rails.logger.debug("Deletion of experiment output #{experiment_size} completed successfully ? #{success}")
      rescue Exception => e
        Rails.logger.debug("Data farming experiment destroy error - #{e}")
      end

      temp_password.destroy
    end

    # drop simulation table
    simulation_runs.collection.drop
    # drop progress bar object
    self.progress_bar_table.drop
    # self-drop
    @@db['experiments_info'].remove({ _id: self.id })
    Experiment.destroy({ _id: self.id })
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

  def simulation_rollback(simulation_run)
    simulation_run.to_sent = true
    simulation_run.save    

    progress_bar_update(simulation_run.index, 'rollback')
  end

  def self.visible_to(user)
    where({ '$or' => [ { user_id: user.id }, { shared_with: { '$in' => [ user.id ] } } ] })
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

  def parameter_uid(entity_group, entity, parameter)
    Experiment.parameter_uid(entity_group, entity, parameter)
  end

  def self.parameter_uid(entity_group, entity, parameter)
    entity_group_id = if entity_group.include?('id') || entity_group.include?('entities')
                        entity_group['id'] || nil
                      else
                        entity_group
                      end

    entity_id = if entity.include?('id') || entity.include?('parameters')
                  entity['id'] || nil
                else
                  entity
                end

    parameter_id = parameter.include?('id') ? parameter['id'] : parameter

    [ entity_group_id, entity_id, parameter_id ].compact.join(ID_DELIM)
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
      if /^((\w)|(-)|(\.))+$/.match(parameter['value']).nil?
        raise SecurityError.new("Insecure parameter given - #{parameter.to_s}")
      end

      parameter_values << parameter['value']

    when 'range'
      # checking parameters for alpha-numeric characters, '_', '-' and '.'
      [ parameter['type'], parameter['step'], parameter['min'], parameter['max'] ].each do |some_value|
        if /^((\w)|(-)|(\.))+$/.match(some_value).nil?
          raise SecurityError.new("Insecure parameter given - #{parameter.to_s}")
        end
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
      [ parameter['mean'], parameter['variance'] ].each do |some_value|
        if /^((\w)|(-)|(\.))+$/.match(some_value).nil?
          raise SecurityError.new("Insecure parameter given - #{parameter.to_s}")
        end
      end

      r_interpreter = Rails.configuration.r_interpreter
      r_interpreter.eval("x <- rnorm(1, #{parameter['mean'].to_f}, #{parameter['variance'].to_f})")
      parameter_values << ('%.3f' % r_interpreter.pull('x').to_f)

    when 'uniform'
      # checking parameters for alpha-numeric characters, '_', '-' and '.'
      [ parameter['min'], parameter['max'] ].each do |some_value|
        if /^((\w)|(-)|(\.))+$/.match(some_value).nil?
          raise SecurityError.new("Insecure parameter given - #{parameter.to_s}")
        end
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

  def execute_doe_method(doe_method_name, parameters_for_doe)
    Rails.logger.debug("Execute doe method: #{doe_method_name} -- #{parameters_for_doe.inspect}")

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

      when '2k-1'
        if parameters_for_doe.size < 3
          #TODO -- change i18n text message or create new
          raise 'experiments.errors.too_few_parameters'
        else
          values = parameters_for_doe.reduce([]) { |sum, parameter_uid|
            parameter = get_parameter_doc(parameter_uid)
            sum << [ {level: -1, value: parameter['min'].to_f}, {level: 1, value: parameter['max'].to_f} ]
          }

          if values.size > 1
            values = values[1..-1].reduce(values.first) { |acc, values| acc.product values }.map { |x| x.flatten }
          else
            values = values.first.map { |x| [x] }
          end

          values = values.select{ |array| array[0..-2].reduce(1) { |acc, item| acc*item[:level] } == array[-1][:level] }
          values = values.map{ |array| array.map{ |item| item[:value] }}

          values
        end

      when '2k-2'
        if parameters_for_doe.size < 5
          #TODO -- change i18n text message or create new
          raise 'experiments.errors.too_few_parameters'
        else
          values = parameters_for_doe.reduce([]) { |sum, parameter_uid|
            parameter = get_parameter_doc(parameter_uid)
            sum << [ {level: -1, value: parameter['min'].to_f}, {level: 1, value: parameter['max'].to_f} ]
          }

          if values.size > 1
            values = values[1..-1].reduce(values.first) { |acc, values| acc.product values }.map { |x| x.flatten }
          else
            values = values.first.map { |x| [x] }
          end

          values = values.select{ |array| array[0..-4].reduce(1) { |acc, item| acc*item[:level] } == array[-2][:level] }
          values = values.select{ |array| array[1..-3].reduce(1) { |acc, item| acc*item[:level] } == array[-1][:level] }
          values = values.map{ |array| array.map{ |item| item[:value] }}

          values
        end

      when *%w(latinHypercube fractionalFactorial nolhDesign)
        if parameters_for_doe.size < 2
          raise 'experiments.errors.too_few_parameters'
        else
          design_file_path = File.join(Rails.root, 'public', 'designs.R')
          Rails.logger.info("""arg <- #{data_frame(parameters_for_doe)} source('#{design_file_path}')
                               design <- #{doe_method_name}(arg) design <- data.matrix(design)""")
          Rails.configuration.r_interpreter.eval("arg <- #{data_frame(parameters_for_doe)}
              source('#{design_file_path}')
              design <- #{doe_method_name}(arg)
              design <- data.matrix(design)")

          values = Rails.configuration.r_interpreter.design.to_a
          values = values.map{|list| list.map{|num| num.round(5)}}
          #Rails.logger.debug("Design: #{values}")

          values
        end
    end
  end

  def data_frame(parameter_list)
    data_frame_list = parameter_list.map do |parameter_uid|
      parameter = get_parameter_doc(parameter_uid)
      # checking parameters for alpha-numeric characters, '_', '-' and '.'
      [ parameter_uid, parameter['min'], parameter['max'], parameter['step'] ].each do |some_value|
        if /^((\w)|(-)|(\.))+$/.match(some_value).nil?
          raise SecurityError.new("Insecure parameter given - #{parameter.to_s}")
        end
      end
      "#{parameter_uid}=c(#{parameter['min']}, #{parameter['max']}, #{parameter['step']})"
    end

    "data.frame(#{data_frame_list.join(',')})"
  end

end
