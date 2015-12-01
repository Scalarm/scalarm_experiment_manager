require 'scalarm/database/simulation_run_factory'
require 'scalarm/database/core/mongo_active_record_utils'

module SimulationRunExtensions
  def rollback!
    Rails.logger.debug("Rolling back SimulationRun: #{id}")

    self.destroy
    experiment.progress_bar_update(self.index, 'rollback')
    self
  end

  def tmp_result
    if self.tmp_results_list.blank?
      attributes['tmp_result']
    else
      self.tmp_results_list.last['result']
    end
  end

  def arguments
    if attributes.include?('input_parameters')
      attributes['input_parameters'].keys.join(',')
    elsif attributes.include?('arguments')
      attributes['arguments']
    else
      ""
    end
  end

  def values
    if attributes.include?('input_parameters')
      attributes['input_parameters'].values.join(',')
    elsif attributes.include?('values')
      attributes['values']
    else
      ""
    end
  end

  def input_parameters
    if attributes.include?('input_parameters')
      attributes['input_parameters']
    elsif attributes.include?('arguments') and attributes.include?('values')
      Hash[*attributes['arguments'].split(',').zip(attributes['values'].split(',')).flatten]
    else
      {}
    end
  end
end

class SimulationRunFactory < Scalarm::Database::SimulationRunFactory
  def self.for_experiment(experiment_id)
    simulation_run_class = super

    # use Experiment Manager's Experiment instead of basic model
    simulation_run_class.send(:prepend, SimulationRunExtensions)

    simulation_run_class
  end
end