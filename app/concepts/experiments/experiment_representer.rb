class ExperimentRepresenter

  def initialize(experiment, user, mode = :full)
    @experiment = experiment
    @user = user
    @mode = mode

    @url_helper = Rails.application.routes.url_helpers
  end

  def to_json
    self.to_h.to_json
  end

  def to_h
    if @mode == :short
      short_form
    elsif @mode == :full
      full_form
    else
      nil
    end
  end

  private

  def short_form
    {
        name: @experiment.name,
        start_at: @experiment.start_at.strftime('%Y-%m-%d %H:%M'),
        end_at: @experiment.end_at.nil? ? nil : @experiment.end_at.strftime('%Y-%m-%d %H:%M'),
        is_running: @experiment.is_running,
        url: api_experiment_path(@experiment.id),
        owned_by_current_user: @user.owns?(@experiment),
        percentage_progress: ((@experiment.get_statistics[2].to_f / @experiment.experiment_size) * 100).to_i
    }
  end

  def full_form
    unnecessary_keys = ["experiment_id", "user_id", "simulation_id", "__hash_attributes", "shared_with"]
    all, sent, done = @experiment.get_statistics

    @experiment.to_h.merge(
        {
            simulation_scenario_url: @url_helper.api_simulation_scenario_path(@experiment.simulation_id),
            simulations_url: @url_helper.api_experiment_simulations_path(@experiment.id),
            size: @experiment.experiment_size,
            all_simulations: all,
            sent_simulations: sent,
            done_simulations: done,
            percentage_progress: ((done.to_f / @experiment.experiment_size) * 100).to_i,
            owned_by_current_user: @user.owns?(@experiment),
            start_at: @experiment.start_at.strftime('%Y-%m-%d %H:%M'),
            end_at: @experiment.end_at.nil? ? nil : @experiment.end_at.strftime('%Y-%m-%d %H:%M'),
            progress_bar: @experiment.progress_bar_color,
            binaries_results_url: @url_helper.results_binaries_experiment_path(@experiment.id),
            structured_results_url: @url_helper.file_with_configurations_experiment_path(@experiment.id)
            # shared_with: @experiment.shared_with.map{|user_id| ScalarmUser.where(id: user_id).first }
     }
    ).delete_if { |key, value| unnecessary_keys.include?(key) }
  end

end