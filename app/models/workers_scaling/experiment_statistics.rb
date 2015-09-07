require 'experiment_extensions/simulation_run'

##
# ExperimentStatistics class calculates various statistics about
# experiment run and execution.
class ExperimentStatistics

  ##
  # Number of running simulations in sequential worker
  RUNNING_SIMULATIONS = 1

  def initialize(experiment, resources_interface)
    @experiment = experiment
    @simulation_run = SimulationRun.for_experiment(@experiment.id)
    @resources_interface = resources_interface
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

  ##
  # Returns throughput for given worker id. Throughout for worker is calculated as:
  #   throughput[sim/s] = (finished_simulations + running_simulation)/(Time.now - start_time)
  def worker_throughput(worker_id)
    calculate_worker_throughput @resources_interface.get_workers_records(query: {_id: worker_id})
  end

  ##
  # Returns throughput of experiment(system) associated with ExperimentStatistics instance.
  # System throughput is calculated as sum of all workers throughput [sim/s].
  def system_throughput
    @resources_interface.get_workers_records
      .map {|worker| calculate_worker_throughput worker}
      .reduce :+
  end

  ##
  # Returns makespan of experiment associated with ExperimentStatistics instance.
  # Makespan is calculated as:
  #   makespan[s] = simulations_to_run/system_throughput
  def makespan
    (@experiment.experiment_size - @experiment.count_done_simulations)/system_throughput
  end

  private

  ##
  # Returns throughput for given worker. For details look at #worker_throughput
  def calculate_worker_throughput(worker)
    ((worker.finished_simulations || 0) + RUNNING_SIMULATIONS)/(Time.now - worker.created_at)
  end

end
