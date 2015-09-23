##
# ExperimentStatistics class calculates various statistics about
# experiment run and execution.
module WorkersScaling
  class ExperimentStatistics

    ##
    # Number of running simulations in sequential worker
    RUNNING_SIMULATIONS = 1

    def initialize(experiment, resources_interface)
      @experiment = experiment
      @resources_interface = resources_interface
    end

    ##
    # Returns throughput for given worker sm_uuid. Throughout for worker is calculated as:
    #   throughput[sim/s] = (finished_simulations + running_simulation)/(Time.now - start_time)
    def worker_throughput(worker_sm_uuid)
      calculate_worker_throughput @resources_interface.get_workers_records(cond: {sm_uuid: worker_sm_uuid}).first
    end

    ##
    # Returns average throughput for given infrastructure
    # Arguments:
    # * infrastructure name
    def infrastructure_throughput(infrastructure_name)
      workers_for_infrastructure = @resources_interface.get_workers_records infrastructure_names: [infrastructure_name]
      workers_for_infrastructure.map {|worker| calculate_worker_throughput worker}
        .reduce(0.0, :+) / Float(workers_for_infrastructure.size)
    end

    ##
    # Returns throughput of experiment(system) associated with ExperimentStatistics instance.
    # System throughput is calculated as sum of all workers throughput [sim/s].
    def system_throughput
      @resources_interface.get_workers_records
        .map {|worker| calculate_worker_throughput worker}
        .reduce 0.0, :+
    end

    ##
    # Returns makespan of experiment associated with ExperimentStatistics instance.
    # Makespan is calculated as:
    #   makespan[s] = simulations_to_run/system_throughput
    def makespan
      @experiment.reload
      (@experiment.experiment_size - @experiment.count_done_simulations)/Float(system_throughput)
    end

    ##
    # Returns statistics about available infrastructure:
    #   * workers_count
    # params:
    #   * infrastructure_names
    # Raises InfrastructureError
    def get_infrastructures_statistics(params = {})
      infrastructure_names = params[:infrastructure_names] || @resources_interface.get_available_infrastructures
      infrastructure_names.map {|name| [name, get_infrastructure_statistics(name, params)]}.to_h
    end

    ##
    # Returns statistics about given infrastructure, statistics description in #get_infrastructures_statistics
    # Raises InfrastructureError
    def get_infrastructure_statistics(name, params = {})
      params.merge! infrastructure_names: [name]
      {
          workers_count: @resources_interface.get_workers_records_count(params)[name],
          average_throughput: infrastructure_throughput(name)
      }
    end

    private

    ##
    # Returns throughput for given worker. For details look at #worker_throughput
    def calculate_worker_throughput(worker)
      ((worker.finished_simulations || 0) + RUNNING_SIMULATIONS)/Float(Time.now - worker.created_at)
    end

  end
end
