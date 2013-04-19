require 'json'
require 'csv'

class DataFarmingExperiment < MongoActiveRecord
  ID_DELIM = '___'

  def self.collection_name
    'experiments'
  end

  def self.get_running_experiments
    instances = []

    collection.find({'is_running' => true}).each do |attributes|
      instances << Object.const_get(name).send(:new, attributes)
    end

    instances
  end

  def is_completed
    ExperimentInstance.count_with_query(self._id) == ExperimentInstance.count_with_query(self._id, {'is_done' => true})
  end

  def simulation
    Simulation.find_by_id self.simulation_id
  end

  def save_and_cache
    Rails.cache.write("data_farming_experiment_#{self._id}", self, :expires_in => 600.seconds)
    self.save
  end

  def get_statistics
    all  = ExperimentInstance.count_with_query(self._id)
    done = ExperimentInstance.count_with_query(self._id, {'is_done' => true})
    sent = ExperimentInstance.count_with_query(self._id, {'to_sent' => false, 'is_done' => false})

    return all, done, sent
  end

  def argument_names
    ExperimentInstance.get_arguments(self.experiment_id)
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

    self.experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          parameters << parameter_uid(entity_group, entity, parameter)
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

  def value_list
    value_list = []

    self.experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          value_list << generate_parameter_values(parameter)
        end
      end
    end

    value_list
  end

  def experiment_size
    self.value_list.reduce(1){|acc, x| acc * x.size}
  end

  def create_result_csv_for(moe_name)

    CSV.generate do |csv|
      csv << self.argument_names.split(',') + [ moe_name ]

      ExperimentInstance.raw_find_by_query(self.experiment_id, { is_done: true }, { fields: %w(values result) }).each do |simulation_doc|
        next if not simulation_doc['result'].has_key?(moe_name)

        values = simulation_doc['values'].split(',').map{|x| '%.4f' % x.to_f}
        csv << values + [ simulation_doc['result'][moe_name] ]
      end
    end

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
    instance = ExperimentInstance.find_by_id(self.experiment_id, 1)
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


  private

  def parameter_uid(entity_group, entity, parameter)
    "#{entity_group["id"]}#{ID_DELIM}#{entity["id"]}#{ID_DELIM}#{parameter["id"]}"
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
    parameter_values = []

    if parameter['parametrizationType'] == 'value'
      parameter_values << parameter["value"].to_f
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
      Rails.logger.debug("Mean: #{parameter['mean'].to_f}")
      Rails.logger.debug("Variance: #{parameter['variance'].to_f}")
      r_interpreter.eval("x <- rnorm(1, #{parameter['mean'].to_f}, #{parameter['variance'].to_f})")
      parameter_values << ('%.3f' % r_interpreter.pull('x').to_f).to_f
    elsif parameter['parametrizationType'] == 'uniform'
      r_interpreter = Rails.configuration.eusas_rinruby
      r_interpreter.eval("x <- runif(1, #{parameter['min'].to_f}, #{parameter['max'].to_f})")
      parameter_values << ('%.3f' % r_interpreter.pull('x').to_f).to_f
    end

    parameter_values
  end

end