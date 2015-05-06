require 'scalarm/database/simulation_run_factory'

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
    super.send(:prepend, SimulationRunExtensions)
  end
end