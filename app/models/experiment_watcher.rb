require 'experiment_instance'
require 'experiment'

class ExperimentWatcher

  class SpawnProxy
    include Spawn
  end

  def self.watch_experiments
    ActiveRecord::Base.connection.reconnect!

    SpawnProxy.new.spawn_block do
      while true do
        DataFarmingExperiment.get_running_experiments.each do |experiment|
          expired_sims = ExperimentInstance.find_expired_instances(experiment.experiment_id, experiment.time_constraint_in_sec)

          expired_sims.each do |simulation|
            simulation.to_sent = true
            simulation.save
          end
        end

        sleep(600)
      end
    end

    ActiveRecord::Base.connection.reconnect!
  end

end
