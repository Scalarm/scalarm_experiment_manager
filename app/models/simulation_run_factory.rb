require 'scalarm/database/simulation_run_factory'
require 'scalarm/database/core/mongo_active_record_utils'

module SimulationRunExtensions
  def rollback!
    Rails.logger.debug("Rolling back SimulationRun: #{id}")

    begin
      Rails.logger.debug("Destroy stdout: #{id}")
      self.destroy_stdout
      Rails.logger.debug("Destroy binary results: #{id}")
      self.destroy_binary_results
    rescue => e
      Rails.logger.info("An exception raised during destroy stdout or binary results - #{e}")
    end

    self.destroy

    Experiment.where(id: self.experiment_id).first.progress_bar_update(self.index, 'rollback')

    self
  end

  def tmp_result
    if self.tmp_results_list.blank?
      attributes['tmp_result']
    else
      self.tmp_results_list.last['result']
    end
  end

  def destroy_binary_results
    sm_proxy = StorageManagerProxy.create(self.experiment_id)

    if sm_proxy.nil?
      raise StandardError.new("No storage manager registered")
    end

    success = false

    begin
      success = sm_proxy.delete_binary_output(self.experiment_id, self.index)
      Rails.logger.debug("Deletion of binary results #{self.experiment_id} #{self.index} completed successfully ? #{success}")
    rescue => e
      Rails.logger.error("Deletion of binary results #{self.experiment_id} #{self.index} raised an exception - #{e}")
    ensure
      sm_proxy.teardown
    end

    if not success
      raise StandardError.new("Couldn't delete binary results for #{self.experiment_id} #{self.index}")
    end
  end

  def destroy_stdout
    sm_proxy = StorageManagerProxy.create(self.experiment_id)

    if sm_proxy.nil?
      raise StandardError.new("No storage manager registered")
    end

    begin
      success = sm_proxy.delete_stdout(self.experiment_id, self.index)
      Rails.logger.debug("Deletion of simulation stdout #{self.experiment_id} #{self.index} completed successfully ? #{success}")
    rescue => e
      Rails.logger.error("Deletion of simulation stdout #{self.experiment_id} #{self.index} raised an exception - #{e}")
    ensure
      sm_proxy.teardown
    end

    if not success
      raise StandardError.new("Couldn't delete simulation stdout for #{self.experiment_id} #{self.index}")
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