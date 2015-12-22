require 'workers_scaling/utils/logger'
module WorkersScaling
  ##
  # Resources usage minimization algorithm will use minimal possible
  # number of resources to fulfil imposed restriction
  class ResourcesUsageMinimization < Algorithm

    def self.algorithm_name
      'Resources usage minimization'
    end

    def self.description
      'Method will use minimal possible amount of resources to finish experiment within execution time limit '\
      'and will try to ensure even resources usage through entire experiment.'
    end

    ##
    # Tolerance used in #time_constraint_check
    # Defines maximal allowed difference at given moment
    # between planned and predicted finish time in percents
    TOLERANCE = 10

    ##
    # Schedules one Worker on each available configuration if Experiment size is greater than configurations number
    # Otherwise uses random subset of available configurations with size equal to Experiment size
    def initial_deployment
      logger.debug 'Initial deployment'
      @experiment.reload
      @resources_interface.get_available_resource_configurations
          .select { |configuration| @resources_interface.current_resource_configuration_limit(configuration) > 0 }
          .shuffle[0..@experiment.size-1]
          .each do |configuration|
        @resources_interface.schedule_workers(1, configuration)
        logger.debug "Initializing configuration: #{configuration}"
      end
    end

    ##
    # Executes action based on result of time_constraint_check
    def execute_algorithm_step
      @experiment.reload
      current_makespan = @experiment_metrics.makespan
      case time_constraint_check(current_makespan, self.planned_finish_time - Time.now)
        when :increase
          increase_computational_power
        when :decrease
          decrease_computational_power
        else
          logger.debug 'Nothing to do'
      end
    end

    ##
    # Returns :increase when predicted time is longer than left time increased by TOLERANCE %
    # Returns :decrease when predicted time is shorter than left time decreased by TOLERANCE %
    # Returns :ok otherwise
    # Arguments:
    # * predicted - predicted time until Experiment end in seconds
    # * left - time left until planned_finish_time in seconds
    def time_constraint_check(predicted, left)
      logger.debug "Time predicted: #{'%.5f' % predicted} s, time left: #{'%.5f' % left} s"
      return :increase if predicted > left * (1 + TOLERANCE/100)
      return :decrease if predicted < left * (1 - TOLERANCE/100)
      :ok
    end

    ##
    # Increases computational power to match required system throughput
    # Does nothing if there are starting Workers already
    # Uses known configurations with highest throughput if limits are not reached
    # If limits in all known configurations are reached, uses random unknown configuration
    def increase_computational_power
      logger.debug 'Need to increase computational power'

      # calculate needed additional throughput
      throughput_needed = @experiment_metrics.target_throughput(self.planned_finish_time) -
          @experiment_metrics.system_throughput
      logger.debug "Additional throughput needed: #{'%.5f' % throughput_needed} sim/s"

      # calculate average configurations throughput
      configurations_throughput = @resources_interface.get_available_resource_configurations.map do |configuration|
        statistics = @experiment_metrics.resource_configuration_statistics(configuration)
        statistics[:average_throughput] = statistics[:throughput] / statistics[:workers_count]
        {resource_configuration: configuration, statistics: statistics}
      end

      # separate configurations currently in use
      used_configurations = configurations_throughput.select { |entity| entity[:statistics][:workers_count] > 0 }
      unused_configurations = configurations_throughput.select { |entity| entity[:statistics][:workers_count] == 0 }

      # sort from highest
      sorted_throughput = used_configurations.sort_by { |configuration| configuration[:average_throughput] }.reverse
      logger.debug "Avg inf throughput: #{sorted_throughput}"

      # iterate over sorted entities until system throughput is increased to desired value
      sorted_throughput.each do |entity|
        break if throughput_needed <= 0
        throughput_needed -= add_workers(entity[:resource_configuration],
                                         entity[:statistics][:average_throughput],
                                         throughput_needed)
        logger.debug "Reduced needed throughput to #{'%.5f' % throughput_needed} sim/s"
      end

      # if throughput is still too low, use other configurations or inform user
      if throughput_needed > 0
        random_unused = unused_configurations
            .select do |entity|
              @resources_interface.current_resource_configuration_limit(entity[:resource_configuration]) > 0
            end
            .sample
        if random_unused.blank?
          logger.debug 'May not meet time requirements'
        else
          # schedule one worker on random unused configuration
          logger.debug 'Need to use unknown configuration'
          add_workers(random_unused[:resource_configuration])
        end
      end
    end

    ##
    # Decreases computational power to match required system throughput
    # Does nothing if there are stopping Workers already
    # Stops Workers with lowest throughput first
    def decrease_computational_power
      logger.debug 'Need to decrease computational power'
      if @resources_interface.count_all_workers(cond: Query::Workers::STOPPING) > 0
        logger.debug 'There are stopping Workers already'
        return
      end

      # calculate excess throughput
      excess_throughput = @experiment_metrics.system_throughput -
          @experiment_metrics.target_throughput(self.planned_finish_time)
      logger.debug "Excess throughput: #{'%.5f' % excess_throughput} sim/s"

      # get all workers with their throughput
      workers_throughput = @resources_interface.get_available_resource_configurations.flat_map do |configuration|
        @resources_interface
            .get_workers_records_list(configuration, cond: Query::Workers::RUNNING_WITH_FINISHED_SIMULATIONS)
            .map do |worker|
              {sm_uuid: worker.sm_uuid, throughput: @experiment_metrics.worker_throughput(worker.sm_uuid)}
            end
      end

      # sort from lowest
      sorted_throughput = workers_throughput.sort_by { |worker| worker[:throughput] }
      logger.debug "Sorted throughput: #{sorted_throughput}"

      # iterate over sorted workers until system throughput is decreased to desired value
      sorted_throughput.each do |worker|
        break if excess_throughput < worker[:throughput]
        @resources_interface.soft_stop_worker(worker[:sm_uuid])
        excess_throughput -= worker[:throughput]
        logger.debug "Stopping Worker with sm_uuid: #{worker[:sm_uuid]}"
        logger.debug "Reduced excess throughput to #{'%.5f' % excess_throughput} sim/s"
      end
    end

    private

    ##
    # Adds workers to given configuration basing on average throughput of configuration and throughput needed
    # If average_throughput is 0, throughput_needed value is ignored and exactly one Worker is added
    # Returns predicted throughput growth
    def add_workers(resource_configuration, average_throughput = 0, throughput_needed = 0)
      workers_needed = if average_throughput > 0
                         if throughput_needed == Float::INFINITY
                           Float::INFINITY
                         else
                           (throughput_needed / average_throughput).ceil
                         end
                       else
                         1
                       end
      logger.debug "Trying to schedule #{workers_needed} Workers on configuration: #{resource_configuration}"
      scheduled = @resources_interface.schedule_workers(workers_needed, resource_configuration).count
      logger.debug "Total of #{scheduled} Workers starting on configuration: #{resource_configuration}"
      scheduled * average_throughput
    end
  end
end
