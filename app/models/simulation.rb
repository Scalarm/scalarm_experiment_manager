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

require 'scalarm/database/model/simulation'

class Simulation < Scalarm::Database::Model::Simulation
  attr_join :user, ScalarmUser
  attr_join :input_writer, SimulationInputWriter
  attr_join :executor, SimulationExecutor
  attr_join :output_reader, SimulationOutputReader
  attr_join :progress_monitor, SimulationProgressMonitor

  def set_up_adapter(adapter_type, current_user, params, mandatory = true)
    if params.include?(adapter_type + '_id') and not params["#{adapter_type}_id"].empty?
      adapter_id = params[adapter_type + '_id'].to_s
      adapter = Object.const_get("Simulation#{adapter_type.camelize}").find_by_id(adapter_id)

      if not adapter.nil? and adapter.user_id == current_user.id
        send(adapter_type + '_id=', adapter.id)
      else
        if mandatory
          raise AdapterNotFoundError.new(adapter_type.camelize, adapter_id)
        end
      end

      # uploading new file
    elsif params.include?(adapter_type)
      adapter_name = if params["#{adapter_type}_name"].blank?
                       params[adapter_type].try(:original_filename) or
                           "unnamed-script-#{Time.now.strftime('%Y-%m-%d-%M-%H')}"
                     else
                       params["#{adapter_type}_name"]
                     end

      unless Utils::get_validation_regexp(:filename).match(adapter_name)
        raise SecurityError.new(t('errors.insecure_filename', param_name: adapter_type))
      end

      adapter = Object.const_get("Simulation#{adapter_type.camelize}").new({
                                                                               name: adapter_name,
                                                                               code: (Utils.read_if_file(params[adapter_type])).gsub("\r\n","\n"),
                                                                               user_id: current_user.id})
      adapter.save
      Rails.logger.debug(adapter)
      send(adapter_type + '_id=', adapter.id)
    else
      if mandatory
        raise MissingAdapterError.new(adapter_type.camelize, adapter_id)
      end
    end
  end

end

class AdapterNotFoundError < StandardError
  attr_reader :adapter_id
  attr_reader :adapter_type

  def initialize(adapter_type, adapter_id)
    @adapter_type = adapter_type
    @adapter_id = adapter_id
  end

end


class MissingAdapterError < StandardError
  attr_reader :adapter_id
  attr_reader :adapter_type

  def initialize(adapter_type, adapter_id)
    @adapter_type = adapter_type
    @adapter_id = adapter_id
  end

end