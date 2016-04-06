class ExperimentWatcher
  CHUNK_SIZE = 10

  def self.watch_experiments
    Rails.logger.info('[experiment_watcher] Watch experiments')

    Thread.new do
      while true do
        Rails.logger.info("[experiment_watcher] #{Time.now} --- running")

        total_number_of_experiments = Experiment.count
        skipped = 0
        while skipped < total_number_of_experiments
          Experiment.where({is_running: true}, {skip: skipped, limit: CHUNK_SIZE}).each do |experiment|
            Rails.logger.info("[experiment_watcher] Checking experiments - start idx: #{skipped}, end idx: #{skipped + CHUNK_SIZE}, total #{total_number_of_experiments}")
            begin
              experiment.simulation_runs.where(is_done: false, to_sent: false).each do |simulation_run|
                Rails.logger.debug("#{Time.now - simulation_run.sent_at} ? #{experiment.time_constraint_in_sec}")
                if Time.now - simulation_run.sent_at >= experiment.time_constraint_in_sec
                  simulation_run.rollback!
                end
              end
            rescue Exception => e
              Rails.logger.error("[experiment_watcher] Error during experiment watching #{e}")
            end
          end

          skipped += CHUNK_SIZE
        end

        sleep(600)
      end
    end
  end

end
