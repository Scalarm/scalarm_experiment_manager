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
      calculate_worker_throughput(@resources_interface.get_worker_record_by_sm_uuid(worker_sm_uuid))
    end

    ##
    # Returns average throughput for given infrastructure
    # Arguments:
    # * infrastructure - hash with infrastructure info
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    def infrastructure_throughput(infrastructure, params = {})
      workers_for_infrastructure = @resources_interface.get_workers_records_list(infrastructure, params)
      workers_for_infrastructure.map {|worker| calculate_worker_throughput(worker)}
        .reduce(0.0, :+) / Float(workers_for_infrastructure.size)
    end

    ##
    # Returns throughput of experiment (system) associated with ExperimentStatistics instance.
    # System throughput is calculated as sum of all workers throughput [sim/s].
    # Arguments:
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    def system_throughput(params = {})
      @resources_interface.get_available_infrastructures.map do |infrastructure|
        @resources_interface.get_workers_records_list(infrastructure, params)
          .map {|worker| calculate_worker_throughput worker}
          .reduce 0.0, :+
      end .reduce 0.0, :+
    end

    ##
    # Returns makespan of experiment associated with ExperimentStatistics instance.
    # Makespan is calculated as:
    #   makespan[s] = simulations_to_run/system_throughput
    # Arguments:
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    def makespan(params = {})
      @experiment.reload
      (@experiment.experiment_size - @experiment.count_done_simulations)/Float(system_throughput(params))
    end

    ##
    # Returns hash with statistics about available infrastructure:
    #   * workers_count
    #   * average throughput
    # Arguments:
    # * infrastructure - hash with infrastructure info
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    # Raises InfrastructureError
    def get_infrastructure_statistics(infrastructure, params = {})
      {
          average_throughput: infrastructure_throughput(infrastructure, params),
          workers_count: @resources_interface.get_workers_records_count(infrastructure, params)
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
