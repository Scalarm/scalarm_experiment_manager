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

  def prepare_code_base
    #code_base_dir = Dir.mktmpdir('code_base')
    ##begin
    #  # use the directory...
    #  open("#{code_base_dir}/input_writer", 'w') { |f| f.write(self.input_writer.code) }
    #  open("#{code_base_dir}/executor", 'w') { |f| f.write(self.executor.code) }
    #  open("#{code_base_dir}/output_reader", 'w') { |f| f.write(self.output_reader.code) }
    #  open("#{code_base_dir}/simulation_binaries.zip", 'w') { |f| f.write(self.simulation_binaries) }
    ##ensure
    #  # remove the directory.
    #  #FileUtils.remove_entry_secure(code_base_dir)
    ##end
    #code_base_dir
  end

  def input_parameters
    parameters = {}

    JSON.parse(self.input_specification).each do |group|
      group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          param_uid = DataFarmingExperiment.parameter_uid(group, entity, parameter)
          parameters[param_uid] = input_parameter_label_for(param_uid)
        end
      end
    end

    parameters
  end

  def input_parameter_label_for(uid)
    entity_group_id, entity_id, parameter_id = uid.split(DataFarmingExperiment::ID_DELIM)

    JSON.parse(self.input_specification).each do |entity_group|
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


end
