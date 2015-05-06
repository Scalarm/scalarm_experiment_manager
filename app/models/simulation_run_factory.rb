require 'scalarm/database/simulation_run_factory'
require 'scalarm/database/core/mongo_active_record_utils'

module SimulationRunExtensions
  def rollback!
    Rails.logger.debug("Rolling back SimulationRun: #{id}")

    self.to_sent = true
    experiment.progress_bar_update(self.index, 'rollback')
    self.save
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