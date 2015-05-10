# Attributes
#_id:
#name:
#description
#input_specification:
#user_id:
#simulation_binaries_id:
#input_writer_id
#executor_id
#output_reader_id
#progress_monitor_id
#created_at: timestamp

require_relative 'simulation_elements/simulation_executor'
require_relative 'simulation_elements/simulation_input_writer'
require_relative 'simulation_elements/simulation_output_reader'
require_relative 'simulation_elements/simulation_progress_monitor'

class Simulation < MongoActiveRecord

  # TODO: when all data in base will be migrated to json-only, this will be unnecessarily
  parse_json_if_string 'input_specification'

  attr_join :user, ScalarmUser

  def self.collection_name
    'simulations'
  end

  def input_writer
    self.input_writer_id.nil? ? nil : SimulationInputWriter.find_by_id(self.input_writer_id)
  end

  def executor
    self.executor_id.nil? ? nil : SimulationExecutor.find_by_id(self.executor_id)
  end

  def output_reader
    self.output_reader_id.nil? ? nil : SimulationOutputReader.find_by_id(self.output_reader_id)
  end

  def progress_monitor
    self.progress_monitor_id.nil? ? nil : SimulationProgressMonitor.find_by_id(self.progress_monitor_id)
  end

  def set_simulation_binaries(filename, binary_data)
    @attributes['simulation_binaries_id'] = @@grid.put(binary_data, :filename => filename)
  end

  def simulation_binaries
    @@grid.get(self.simulation_binaries_id).read
  end

  def simulation_binaries_name
    @@grid.get(self.simulation_binaries_id).filename
  end

  def simulation_binaries_size
    @@grid.get(self.simulation_binaries_id).file_length
  end

  def destroy
    @@grid.delete self.simulation_binaries_id
    super
  end

  def input_parameters
    parameters = {}

    self.input_specification.each do |group|
      group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          param_uid = Experiment.parameter_uid(group, entity, parameter)
          parameters[param_uid] = input_parameter_label_for(param_uid)
        end
      end
    end

    parameters
  end

  def input_parameter_label_for(uid)
    split_uid = uid.split(Experiment::ID_DELIM)
    entity_group_id, entity_id, parameter_id = split_uid[-3], split_uid[-2], split_uid[-1]

    self.input_specification.each do |entity_group|
      if entity_group['id'] == entity_group_id
        entity_group['entities'].each do |entity|
          if entity['id'] == entity_id
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

  def self.visible_to(user)
    where({'$or' => [{user_id: user.id}, {shared_with: {'$in' => [user.id]}}, {is_public: true}]})
  end

  def set_up_adapter(adapter_type, params, current_user, mandatory = true)
    validate(
        "#{adapter_type}_id".to_sym => [:optional, :security_default],
        "#{adapter_type}_name".to_sym => [:optional, :security_default]
    )

    if params.include?(adapter_type + '_id') and not params["#{adapter_type}_id"].empty?
      adapter_id = params[adapter_type + '_id'].to_s
      adapter = Object.const_get("Simulation#{adapter_type.camelize}").find_by_id(adapter_id)

      if not adapter.nil? and adapter.user_id == current_user.id
        send(adapter_type + '_id=', adapter.id)
      else
        if mandatory
          flash[:error] = t('simulations.create.adapter_not_found', {adapter: adapter_type.camelize, id: adapter_id})
          raise Exception.new("Setting up Simulation#{adapter_type.camelize} is mandatory")
        end
      end

      # uploading new file
    elsif params.include?(adapter_type)
      unless Utils::get_validation_regexp(:filename).match(params[adapter_type].original_filename)
        flash[:error] = t('errors.insecure_filename', param_name: adapter_type)
        raise SecurityError.new(t('errors.insecure_filename', param_name: adapter_type))
      end

      adapter_name = if params["#{adapter_type}_name"].blank?
                       params[adapter_type].original_filename
                     else
                       params["#{adapter_type}_name"]
                     end

      adapter = Object.const_get("Simulation#{adapter_type.camelize}").new({
                                                                               name: adapter_name,
                                                                               code: Utils.read_if_file(params[adapter_type]),
                                                                               user_id: current_user.id})
      adapter.save
      Rails.logger.debug(adapter)
      send(adapter_type + '_id=', adapter.id)
    else
      if mandatory
        flash[:error] = t('simulations.create.mandatory_adapter', {adapter: adapter_type.camelize, id: adapter_id})
        raise Exception("Setting up Simulation#{adapter_type.camelize} is mandatory")
      end
    end
  end

end
