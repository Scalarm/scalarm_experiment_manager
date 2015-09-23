##
# Sample Workers scaling algorithm.
module WorkersScaling
  class SampleAlgorithm < Algorithm

    ##
    # Tolerance used in #time_constraint_check
    # Defines maximal allowed difference in seconds
    # between planned and predicted finish time
    TOLERANCE = 60

    ##
    # Arguments:
    # * instance of Experiment
    # * id of User starting Algorithm
    # * dictionary mapping infrastructure name to maximal Workers amount
    # * desired time of end of Experiment
    # Creates instances of ExperimentResourcesInterface and ExperimentStatistics
    def initialize(experiment, user_id, inf_limits, planned_finish_time)
      @experiment = experiment
      @resources_interface = ExperimentResourcesInterface.new @experiment.id, user_id
      @experiment_statistics = ExperimentStatistics.new @experiment, @resources_interface
      @infrastructure_limits = inf_limits
      @planned_finish_time = planned_finish_time
    end

    def modify_limits(inf_limits)
      @infrastructure_limits = inf_limits
    end

    def initial_deployment
      LOGGER.debug 'Initial deployment'
      @infrastructure_limits.each { |name, limit| @resources_interface.schedule_workers 1, name, host: 'localhost' if limit > 0 }
    end

    def experiment_status_check
      @experiment = @experiment.reload
      current_makespan = @experiment_statistics.makespan
      case time_constraint_check(current_makespan, @planned_finish_time - Time.now)
        when :increase
          increase_computational_power
        when :decrease
          decrease_computational_power
        else
          LOGGER.debug 'Nothing to do'
      end
    end

    def time_constraint_check(predicted, left)
      LOGGER.debug "Time predicted: #{predicted} s, time left: #{left} s"
      return :increase if predicted > left + TOLERANCE
      return :decrease if predicted < left - TOLERANCE
      :ok
    end

    def increase_computational_power
      LOGGER.debug 'Need to increase computational power'
      starting_workers = @resources_interface
                             .get_workers_records_count(cond: {state: {'$in' => [:created, :initializing]}})
                             .map { |_, count| count}
                             .reduce(0.0) { |sum, count| sum + count }
      if starting_workers > 0
        LOGGER.debug 'There are starting workers already'
        return
      end

      done_sims = @experiment.get_statistics[2]
      target_throughput = (@experiment.size - done_sims) / Float(@planned_finish_time - Time.now)
      needed_additional_throughput = target_throughput - @experiment_statistics.system_throughput
      LOGGER.debug "Target throughput: #{target_throughput} sim/s"
      LOGGER.debug "Current throughput: #{@experiment_statistics.system_throughput} sim/s"
      LOGGER.debug "Additional throughput needed: #{needed_additional_throughput} sim/s"

      infrastructures_statistics = @experiment_statistics.get_infrastructures_statistics cond: {state: :running}
      current_limits = @infrastructure_limits.map do |infrastructure, limit|
        limit -= infrastructures_statistics[infrastructure][:workers_count] if infrastructures_statistics[infrastructure]
        [infrastructure, limit]
      end .to_h
      LOGGER.debug "Inf limits left: #{current_limits}"

      # TODO: calculate avg throughput for unused infrastructures basing on ECU?
      inf_throughput = infrastructures_statistics.delete_if { |_, statistics| statistics[:workers_count] == 0 }
                           .map { |name, statistics| {name: name, average_throughput: statistics[:average_throughput]} }
      inf_throughput.sort_by! { |infrastructure| infrastructure[:average_throughput]}
      inf_throughput.reverse!
      LOGGER.debug "Avg inf throughput: #{inf_throughput}"

      inf_throughput.each do |infrastructure|
        break if needed_additional_throughput <= 0
        next if current_limits[infrastructure[:name]].nil? or current_limits[infrastructure[:name]] == 0
        needed_additional_workers = [(needed_additional_throughput / infrastructure[:average_throughput]).ceil,
                                     current_limits[infrastructure[:name]]].min
        needed_additional_throughput -= needed_additional_workers * infrastructure[:average_throughput]
        current_limits[infrastructure[:name]] -= needed_additional_workers
        @resources_interface.schedule_workers needed_additional_workers, infrastructure[:name], host: 'localhost'
        LOGGER.debug "Starting #{needed_additional_workers} workers on infrastructure: #{infrastructure[:name]}"
        LOGGER.debug "Reduced needed throughput by #{needed_additional_workers * infrastructure[:average_throughput]} sim/s to #{needed_additional_throughput} sim/s"
      end

      if needed_additional_throughput > 0
        # TODO: send one SiM to random unused infrastructure
        LOGGER.debug 'May not meet time requirements' # if no unused infrastructure is left
        # TODO: inform user that planned_finish_time cannot be fulfilled with current limits
      end
    end

    def decrease_computational_power
      LOGGER.debug 'Need to decrease computational power'
      stopping_workers = @resources_interface
                             .get_workers_records_count(cond: {'$or' => [{simulations_left: {'$exists' => true}},
                                                                         state: :terminating]})
                             .map { |_, count| count}
                             .reduce(0.0) { |sum, count| sum + count }
      if stopping_workers > 0
        LOGGER.debug 'There are stopping workers already'
        return
      end

      done_sims = @experiment.get_statistics[2]
      target_throughput = (@experiment.size - done_sims) / [Float(@planned_finish_time - Time.now), 0.0].max
      excess_throughput = @experiment_statistics.system_throughput - target_throughput
      LOGGER.debug "Target throughput: #{target_throughput} sim/s"
      LOGGER.debug "Current throughput: #{@experiment_statistics.system_throughput} sim/s"
      LOGGER.debug "Excess throughput: #{excess_throughput} sim/s"

      workers_throughput = @resources_interface.get_workers_records.map do |worker|
        {sm_uuid: worker.sm_uuid, throughput: @experiment_statistics.worker_throughput(worker.sm_uuid)}
      end
      workers_throughput.sort_by! { |worker| worker[:throughput]}
      LOGGER.debug "Workers throughput: #{workers_throughput}"

      workers_throughput.each do |worker|
        break if excess_throughput < worker[:throughput]
        @resources_interface.limit_worker_simulations worker[:sm_uuid], 1
        excess_throughput -= worker[:throughput]
        LOGGER.debug "Stopping worker with sm_uuid: #{worker[:sm_uuid]}"
        LOGGER.debug "Reduced excess throughput by #{worker[:throughput]} sim/s to #{excess_throughput} sim/s"
      end
    end

  end
end