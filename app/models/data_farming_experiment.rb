require 'json'

class DataFarmingExperiment < MongoActiveRecord
  ID_DELIM = "___"


  def self.collection_name
    'experiments'
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
    first_instance = ExperimentInstance.find_by_id(self._id, 1)

    first_instance.arguments.split(",").map{|arg| ParameterForm.parameter_uid_for_r(arg)}.join(",")
  end

  def range_arguments
    params_with_range = []

    self.experiment_input.each do |entity_group|
      entity_group["entities"].each do |entity|
        entity["parameters"].each do |parameter|
          if parameter["parametrizationType"] == "range"
            params_with_range << parameter_uid(entity_group, entity, parameter)
          end
        end
      end
    end

    params_with_range
  end

  def parametrization_of(parameter_uid)
    self.experiment_input.each do |entity_group|
      entity_group["entities"].each do |entity|
        entity["parameters"].each do |parameter|
          return parameter_uid, parameter.parametrizationType if parameter_uid(entity_group, entity, parameter) == parameter_uid
        end
      end
    end

    nil
  end

  def parametrization_values
    parameters = []

    self.experiment_input.each do |entity_group|
      entity_group["entities"].each do |entity|
        entity["parameters"].each do |parameter|
          parameters += get_parametrization_values(entity_group, entity, parameter)
        end
      end
    end

    parameters.join('|')
  end

  def parameters
    parameters = []

    self.experiment_input.each do |entity_group|
      entity_group["entities"].each do |entity|
        entity["parameters"].each do |parameter|
          parameters << parameter_uid(entity_group, entity, parameter)
        end
      end
    end

    parameters
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