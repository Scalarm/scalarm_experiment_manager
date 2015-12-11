##
# All methods are invoked with experiment and user as arguments
class ExperimentStatistics

  # @param experiment [Experiment]
  # @param user [ScalarmUser]
  def initialize(experiment, user)
    @experiment = experiment
    @user = user
  end

  # @return [Hash] hash containing simulations statistics
  def simulations_statistics
    sims_generated, sims_sent, sims_done = @experiment.get_statistics

    if sims_generated > @experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations generated for experiment #{experiment.inspect}")
      sims_generated = @experiment.experiment_size
    end

    if sims_done > @experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations done and sent for experiment #{experiment.inspect}")
      sims_done = @experiment.experiment_size
    end

    if sims_done + sims_sent > @experiment.experiment_size
      sims_sent = @experiment.experiment_size - sims_done
    end

    #if sims_generated > @experiment.experiment_size
    #  @experiment.experiment_size = sims_generated
    #  @experiment.save
    #end

    if @experiment.experiment_size != 0
      percentage = (sims_done.to_f / @experiment.experiment_size) * 100
    else
      percentage = 0
    end

    stats = {
        all: @experiment.experiment_size, sent: sims_sent, done_num: sims_done,
        done_percentage: "'%.2f'" % (percentage),
        generated: [sims_generated, @experiment.experiment_size].min
    }

    if sims_done > 0 and (rand() < (sims_done.to_f / @experiment.experiment_size) or sims_done == @experiment.experiment_size)
      execution_time = @experiment.simulation_runs.where({is_done: true}, fields: %w(sent_at done_at)).reduce(0) do |acc, simulation_run|
        if simulation_run.done_at and simulation_run.sent_at
          acc += simulation_run.done_at - simulation_run.sent_at
        else
          acc
        end
      end
      stats['avg_execution_time'] = (execution_time / sims_done).round(2)
    end

    stats
  end

  # @return [Hash] hash containing progress bar colors data
  def progress_bar
    {progress_bar: "[#{@experiment.progress_bar_color.join(',')}]"}
  end

  # @return [Hash] hash containing information whether experiment is completed
  def completed
    {completed: @experiment.completed?}
  end

  # @return [Hash] hash containing predicted finish time of experiment
  def predicted_finish_time
    makespan = WorkersScaling::ExperimentMetricsFactory.create_metrics(@experiment, @user.id).makespan
    {predicted_finish_time: ((makespan == Float::INFINITY) ? -1 : (Time.now + makespan).to_i)}
  end

  # @return [Hash] hash containing information whether workers scaling algorithm is active
  def workers_scaling_active
    {workers_scaling_active: (WorkersScaling::Algorithm.where(experiment_id: @experiment.id).count > 0)}
  end
end