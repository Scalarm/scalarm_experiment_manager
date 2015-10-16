##
# Sample Workers scaling algorithm.
module WorkersScaling
  class SampleAlgorithm < Algorithm

    ##
    # Tolerance used in #time_constraint_check
    # Defines maximal allowed difference at given moment
    # between planned and predicted finish time in percents
    TOLERANCE = 10

    ##
    # Arguments: see Algorithm#initialize
    def initialize(experiment, user_id, allowed_infrastructures, planned_finish_time, params = {})
      super(experiment, user_id, allowed_infrastructures, planned_finish_time, params)
    end

    ##
    # Schedules one Worker on each available infrastructure if Experiment size is greater than infrastructures number
    # Otherwise uses random subset of available infrastructures with size equal to Experiment size
    def initial_deployment
      LOGGER.debug 'Initial deployment'
      @experiment.reload
      @resources_interface.get_available_infrastructures
          .select { |infrastructure| @resources_interface.current_infrastructure_limit(infrastructure) > 0 }
          .shuffle[0..@experiment.size-1]
          .each do |infrastructure|
        @resources_interface.schedule_workers(1, infrastructure)
        LOGGER.debug "Initializing infrastructure: #{infrastructure}"
      end
    end

    ##
    # Executes action based on result of time_constraint_check
    def experiment_status_check
      LOGGER.debug 'experiment_status_check'
      @experiment.reload
      current_makespan = @experiment_statistics.makespan(cond: Query::RUNNING_WORKERS)
      case time_constraint_check(current_makespan, @planned_finish_time - Time.now)
        when :increase
          increase_computational_power
        when :decrease
          decrease_computational_power
        else
          LOGGER.debug 'Nothing to do'
      end
    end

    ##
    # Returns :increase when predicted time is longer than left time increased by TOLERANCE %
    # Returns :decrease when predicted time is shorter than left time decreased by TOLERANCE %
    # Returns :ok otherwise
    # Arguments:
    # * predicted - predicted time until Experiment end in seconds
    # * left - time left until @planned_finish_time in seconds
    def time_constraint_check(predicted, left)
      LOGGER.debug "Time predicted: #{'%.5f' % predicted} s, time left: #{'%.5f' % left} s"
      return :increase if predicted > left * (1 + TOLERANCE/100)
      return :decrease if predicted < left * (1 - TOLERANCE/100)
      :ok
    end

    ##
    # Increases computational power to match required system throughput
    # Does nothing if there are starting Workers already
    # Uses known infrastructures with highest throughput if limits are not reached
    # If limits in all known infrastructures are reached, uses random unknown infrastructure
    def increase_computational_power
      LOGGER.debug 'Need to increase computational power'
      if @resources_interface.count_all_workers(cond: Query::STARTING_WORKERS) > 0
        LOGGER.debug 'There are starting Workers already'
        return
      end

      # calculate needed additional throughput
      throughput_needed = @experiment_statistics.target_throughput(@planned_finish_time) -
                          @experiment_statistics.system_throughput
      LOGGER.debug "Additional throughput needed: #{'%.5f' % throughput_needed} sim/s"

      # calculate average infrastructures throughput
      infrastructures_throughput = @resources_interface.get_available_infrastructures.map do |infrastructure|
        statistics = @experiment_statistics.get_infrastructure_statistics(infrastructure, cond: Query::RUNNING_WORKERS)
        {infrastructure: infrastructure, statistics: statistics}
      end

      # separate infrastructures currently in use
      used_infrastructures = infrastructures_throughput.select { |entity| entity[:statistics][:workers_count] > 0 }
      unused_infrastructures = infrastructures_throughput.select { |entity| entity[:statistics][:workers_count] == 0 }
      # TODO: calculate avg throughput for unused infrastructures basing on ECU?

      # sort from highest
      sorted_throughput = used_infrastructures.sort_by { |infrastructure| infrastructure[:average_throughput] }.reverse
      LOGGER.debug "Avg inf throughput: #{sorted_throughput}"

      # iterate over sorted entities until system throughput is increased to desired value
      sorted_throughput.each do |entity|
        break if throughput_needed <= 0
        throughput_needed -= add_workers(entity[:infrastructure],
                                         entity[:statistics][:average_throughput],
                                         throughput_needed)
        LOGGER.debug "Reduced needed throughput to #{'%.5f' % throughput_needed} sim/s"
      end

      # if throughput is still too low, use other infrastructures or inform user
      if throughput_needed > 0
        if unused_infrastructures.blank?
          # TODO: inform user that planned_finish_time cannot be fulfilled with current limits
          LOGGER.debug 'May not meet time requirements'
        else
          # schedule one worker on random unused infrastructure
          random_unused = unused_infrastructures
                    .select { |entity| @resources_interface.current_infrastructure_limit(entity[:infrastructure]) > 0 }
                    .sample[:infrastructure]
          add_workers(random_unused[:infrastructure])
        end
      end
    end

    ##
    # Decreases computational power to match required system throughput
    # Does nothing if there are stopping Workers already
    # Stops Workers with lowest throughput first
    def decrease_computational_power
      LOGGER.debug 'Need to decrease computational power'
      if @resources_interface.count_all_workers(cond: Query::STOPPING_WORKERS) > 0
        LOGGER.debug 'There are stopping Workers already'
        return
      end

      # calculate excess throughput
      excess_throughput = @experiment_statistics.system_throughput -
                          @experiment_statistics.target_throughput(@planned_finish_time)
      LOGGER.debug "Excess throughput: #{'%.5f' % excess_throughput} sim/s"

      # get all workers with their throughput
      workers_throughput = @resources_interface.get_available_infrastructures.flat_map do |infrastructure|
        @resources_interface.get_workers_records_list(infrastructure, cond: Query::RUNNING_WORKERS).map do |worker|
          {sm_uuid: worker.sm_uuid, throughput: @experiment_statistics.worker_throughput(worker.sm_uuid)}
        end
      end

      # sort from lowest
      sorted_throughput = workers_throughput.sort_by { |worker| worker[:throughput] }
      LOGGER.debug "Sorted throughput: #{sorted_throughput}"

      # iterate over sorted workers until system throughput is decreased to desired value
      sorted_throughput.each do |worker|
        break if excess_throughput < worker[:throughput]
        @resources_interface.soft_stop_worker(worker[:sm_uuid])
        excess_throughput -= worker[:throughput]
        LOGGER.debug "Stopping Worker with sm_uuid: #{worker[:sm_uuid]}"
        LOGGER.debug "Reduced excess throughput to #{'%.5f' % excess_throughput} sim/s"
      end
    end

    # private

    ##
    # Adds workers to given infrastructure basing on average throughput of infrastructure and throughput needed
    # If average_throughput is 0, throughput_needed value is ignored and exactly one Worker is added
    # Returns predicted throughput growth
    def add_workers(infrastructure, average_throughput = 0, throughput_needed = 0)
      workers_needed = average_throughput > 0 ? (throughput_needed / average_throughput).ceil : 1
      LOGGER.debug "Starting #{workers_needed} Workers on infrastructure: #{infrastructure}"
      @resources_interface.schedule_workers(workers_needed, infrastructure).count * average_throughput
    end
  end
end
