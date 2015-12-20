require 'workers_scaling/utils/query'
module WorkersScaling
  ##
  # ExperimentMetrics class calculates various metrics about
  # experiment run and execution.
  class ExperimentMetrics

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
    # By default only running workers are included into calculations.
    def infrastructure_throughput(infrastructure, params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
      workers_for_infrastructure = @resources_interface.get_workers_records_list(infrastructure, params)
      workers_for_infrastructure.map {|worker| calculate_worker_throughput(worker)}
        .reduce(0.0, :+) / Float(workers_for_infrastructure.size)
    end

    ##
    # Returns throughput of experiment (system) associated with ExperimentMetrics instance.
    # System throughput is calculated as sum of all workers throughput [sim/s].
    # Arguments:
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    # By default only running workers are included into calculations.
    def system_throughput(params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
      @resources_interface.get_enabled_resource_configurations.map do |infrastructure|
        @resources_interface.get_workers_records_list(infrastructure, params)
          .map {|worker| calculate_worker_throughput worker}
          .reduce 0.0, :+
      end .reduce 0.0, :+
    end

    ##
    # Returns throughput needed to finish Experiment in desired time
    # Target throughput is calculated as:
    #   throughput[sim/s] = simulations_to_run/(planned_finish_time - Time.now)
    def target_throughput(planned_finish_time)
      simulations_to_run = count_not_finished_simulations
      return simulations_to_run if simulations_to_run == 0.0
      simulations_to_run / [Float(planned_finish_time - Time.now), 0.0].max
    end

    ##
    # Returns makespan of experiment associated with ExperimentMetrics instance.
    # Makespan is calculated as:
    #   makespan[s] = simulations_to_run/system_throughput
    # Arguments:
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    # By default only running workers are included into calculations.
    def makespan(params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
      simulations_to_run = count_not_finished_simulations
      return simulations_to_run if simulations_to_run == 0.0
      simulations_to_run / Float(system_throughput(params))
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
    # By default only running workers are included into calculations.
    # Raises InfrastructureError
    def get_infrastructure_statistics(infrastructure, params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
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
    
    ##
    # Return number of simulations to run
    def count_not_finished_simulations
      @experiment.reload
      [@experiment.size - @experiment.count_done_simulations, 0].max
    end

  end
end
