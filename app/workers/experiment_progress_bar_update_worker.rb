class ExperimentProgressBarUpdateWorker
  include Sidekiq::Worker

  def perform(experiment_id)
    experiment = Experiment.where(id: experiment_id).first

    if experiment.nil?
      logger.error "Couldn't find experiment '#{experiment_id}' - no progress bar update will be made"
      return
    end

    logger.debug "Updating all progress bars --- #{Time.now - experiment.start_at}"

    experiment.update_all_bars
  end

end
