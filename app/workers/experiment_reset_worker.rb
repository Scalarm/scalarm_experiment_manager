class ExperimentResetWorker
  include Sidekiq::Worker

  def perform(experiment_id)
    logger.info "Reset of an experiment '#{experiment_id}' start..."

    experiment = Experiment.where(id: experiment_id).first
    if experiment.nil?
      logger.error "Couldn't find experiment '#{experiment_id}' so there is no need to reset it"
      return
    end

    # 1. remove all binary results of simulation runs
    experiment.delete_binary_results

    # 2. remove all simulation runs
    experiment.simulation_runs.each(&:destroy)
    
    # 3. reset counters
    experiment.delete_file_with_ids

    # 4. update progress bar
    experiment.create_progress_bar_table.drop
    experiment.insert_initial_bar

    # 5. save experiment
    experiment.save

    logger.info "Reset of the experiment '#{experiment_id}' is completed"
  end

end
