require 'workers_scaling/utils/query'
module WorkersScaling
  ##
  # ExperimentMetrics class calculates various metrics about
  # experiment run and execution.
  class ExperimentMetrics

    ##
    # Number of running simulations in sequential worker
    RUNNING_SIMULATIONS = 1

    ##
    # @param experiment [Experiment]
    # @param resources_interface [ExperimentResourcesInterface]
    def initialize(experiment, resources_interface)
      @experiment = experiment
      @resources_interface = resources_interface
    end

    ##
    # Returns throughput for worker with given sm_uuid. Throughout for worker is calculated as:
    #   throughput[sim/s] = (finished_simulations + running_simulation)/(Time.now - start_time)
    # @param worker_sm_uuid [BSON::ObjectId, String]
    # @return [Float] throughput of worker
    def worker_throughput(worker_sm_uuid)
      calculate_worker_throughput(@resources_interface.get_worker_record_by_sm_uuid(worker_sm_uuid))
    end

    ##
    # Returns throughput for given resource_configuration
    # By default only running workers are included into calculations.
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions
    # @option params [Hash] :opts query options
    # @return [Float] throughput of given resource configuration
    def resource_configuration_throughput(resource_configuration, params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
      @resources_interface.get_workers_records_list(resource_configuration, params)
          .map {|worker| calculate_worker_throughput(worker)}
          .reduce(0.0, :+)
    end

    ##
    # Returns throughput of experiment (system) associated with ExperimentMetrics instance.
    # System throughput is calculated as sum of all resource configurations throughput [sim/s].
    # By default only running workers are included into calculations.
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions
    # @option params [Hash] :opts query options
    # @return [Float] throughput of experiment
    def system_throughput(params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
      @resources_interface.get_enabled_resource_configurations
          .map {|configuration| resource_configuration_throughput(configuration, params)}
          .reduce(0.0, :+)
    end

    ##
    # Returns throughput needed to finish Experiment in desired time
    # Target throughput is calculated as:
    #   throughput[sim/s] = simulations_to_run/(planned_finish_time - Time.now)
    # @param planned_finish_time [Time]
    # @return [Float] target throughput
    def target_throughput(planned_finish_time)
      simulations_to_run = count_not_finished_simulations
      return simulations_to_run if simulations_to_run == 0.0
      simulations_to_run / [Float(planned_finish_time - Time.now), 0.0].max
    end

    ##
    # Returns makespan of experiment associated with ExperimentMetrics instance.
    # Makespan is calculated as:
    #   makespan[s] = simulations_to_run/system_throughput
    # By default only running workers are included into calculations.
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions
    # @option params [Hash] :opts query options
    # @return [Float] predicted time until experiment end in seconds
    def makespan(params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
      simulations_to_run = count_not_finished_simulations
      return simulations_to_run if simulations_to_run == 0.0
      simulations_to_run / Float(system_throughput(params))
    end

    ##
    # Returns hash with statistics about available resource_configuration:
    #   * throughput
    #   * workers_count
    # By default only running workers are included into calculations.
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions
    # @option params [Hash] :opts query options
    def resource_configuration_statistics(resource_configuration, params = {})
      params[:cond] = Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS unless params.has_key? :cond
      {
          throughput: resource_configuration_throughput(resource_configuration, params),
          workers_count: @resources_interface.get_workers_records_count(resource_configuration, params)
      }
    end

    private

    ##
    # Returns throughput for given worker. For details look at #worker_throughput
    # @param worker [PrivateMachineRecord, PlGridJob, CloudVmRecord, DummyRecord]
    # @return [Float] throughput of worker
    def calculate_worker_throughput(worker)
      ((worker.finished_simulations || 0) + RUNNING_SIMULATIONS)/Float(Time.now - worker.created_at)
    end

    ##
    # Return number of simulations to run
    # @return [Fixnum] number of not finished simulations
    def count_not_finished_simulations
      @experiment.reload
      [@experiment.size - @experiment.count_done_simulations, 0].max
    end

  end
end
