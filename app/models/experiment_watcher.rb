class ExperimentWatcher

  def self.watch_experiments
    Rails.logger.debug('[experiment_watcher] Watch experiments')

    Thread.new do
      while true do
        Rails.logger.debug("[experiment_watcher] #{Time.now} --- running")
        Experiment.where(is_running: true).each do |experiment|
          #Rails.logger.debug("Experiment: #{experiment}")
          begin
            experiment.simulation_runs.where(is_done: false, to_sent: false).each do |simulation_run|
              Rails.logger.debug("#{Time.now - simulation_run.sent_at} ? #{experiment.time_constraint_in_sec}")
              if Time.now - simulation_run.sent_at >= experiment.time_constraint_in_sec
                experiment.simulation_rollback(simulation_run)
              end
            end
          rescue Exception => e
            Rails.logger.debug("Error during experiment watching #{e}")
          end
        end

        sleep(600)
      end
    end
  end

end
