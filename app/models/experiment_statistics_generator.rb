##
# All methods are invoked with experiment and user as arguments
class ExperimentStatisticsGenerator

  # @param experiment [Experiment]
  # @return [Hash] hash containing simulations statistics
  def self.simulations_statistics(experiment, _=nil)
    sims_generated, sims_sent, sims_done = experiment.get_statistics

    if sims_generated > experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations generated for experiment #{experiment.inspect}")
      sims_generated = experiment.experiment_size
    end

    if sims_done > experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations done and sent for experiment #{experiment.inspect}")
      sims_done = experiment.experiment_size
    end

    if sims_done + sims_sent > experiment.experiment_size
      sims_sent = experiment.experiment_size - sims_done
    end

    #if sims_generated > @experiment.experiment_size
    #  @experiment.experiment_size = sims_generated
    #  @experiment.save
    #end


    if experiment.experiment_size != 0
      percentage = (sims_done.to_f / experiment.experiment_size) * 100
    else
      percentage = 0
    end

    stats = {
        all: experiment.experiment_size, sent: sims_sent, done_num: sims_done,
        done_percentage: "'%.2f'" % (percentage),
        generated: [sims_generated, experiment.experiment_size].min
    }

    # TODO - mean execution time and predicted time to finish the experiment
    if sims_done > 0 and (rand() < (sims_done.to_f / experiment.experiment_size) or sims_done == experiment.experiment_size)
      execution_time = experiment.simulation_runs.where({is_done: true}, fields: %w(sent_at done_at)).reduce(0) do |acc, simulation_run|
        if simulation_run.done_at and simulation_run.sent_at
          acc += simulation_run.done_at - simulation_run.sent_at
        else
          acc
        end
      end
      stats['avg_execution_time'] = (execution_time / sims_done).round(2)

      #  predicted_finish_time = (Time.now - experiment.start_at).to_f / 3600
      #  predicted_finish_time /= (instances_done.to_f / experiment.experiment_size)
      #  predicted_finish_time_h = predicted_finish_time.floor
      #  predicted_finish_time_m = ((predicted_finish_time.to_f - predicted_finish_time_h.to_f)*60).to_i
      #
      #  predicted_finish_time = ''
      #  predicted_finish_time += "#{predicted_finish_time_h} hours"  if predicted_finish_time_h > 0
      #  predicted_finish_time += ' and ' if (predicted_finish_time_h > 0) and (predicted_finish_time_m > 0)
      #  predicted_finish_time +=  "#{predicted_finish_time_m} minutes" if predicted_finish_time_m > 0
      #
      #  partial_stats["predicted_finish_time"] = predicted_finish_time
    end

    stats
  end

  # @param experiment [Experiment]
  # @param _ [ScalarmUser] unused param
  # @return [Hash] hash containing progress bar colors data
  def self.progress_bar(experiment, _=nil)
    {progress_bar: "[#{experiment.progress_bar_color.join(',')}]"}
  end

  # @param experiment [Experiment]
  # @param _ [ScalarmUser] unused param
  # @return [Hash] hash containing information whether experiment is completed
  def self.completed(experiment, _=nil)
    {completed: experiment.completed?}
  end

  # @param experiment [Experiment]
  # @param current_user [ScalarmUser]
  # @return [Hash] hash containing predicted finish time of experiment
  def self.predicted_finish_time(experiment, current_user)
    makespan = WorkersScaling::ExperimentStatisticsFactory.create_statistics(experiment, current_user.id).makespan
    {predicted_finish_time: ((makespan == Float::INFINITY) ? -1 : (Time.now + makespan).to_i)}
  end

  # @param experiment [Experiment]
  # @param current_user [ScalarmUser]
  # @return [Hash] hash containing information whether workers scaling algorithm is active
  def self.workers_scaling_active(experiment, _=nil)
    {workers_scaling_active: (WorkersScaling::Algorithm.where(experiment_id: experiment.id).count > 0)}
  end
end