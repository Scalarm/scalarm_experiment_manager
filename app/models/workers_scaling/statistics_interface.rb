require 'experiment_extensions/simulation_run'

class StatisticsInterface

  def initialize(experiment_id)
    @simulation_run = SimulationRun.for_experiment(experiment_id)
  end

  ##
  # Returns SimulationRuns with given params
  # params:
  #   * opts
  #   * cond
  def for_simulation_runs(params = {})
    query = params[:cond] || {}
    opts= params[:opts] || {}
    @simulation_run.where(query, opts).to_a
  end

end
