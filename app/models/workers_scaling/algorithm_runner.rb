require 'workers_scaling/utils/logger'
module WorkersScaling
  ##
  # Scheduler to run Algorithm decision loop periodically
  class AlgorithmRunner

    RUNNER_INTERVAL = 15.seconds
    THREADS_NUMBER = 4

    ##
    # Runs periodically and loads some data from all saved Algorithms
    # If next_execution_time has passed, starts execute_and_schedule for this algorithm
    def self.start
      Thread.new do
        begin
          while true do
            LOGGER.debug 'Entering Algorithm Runner loop'
            work_queue = Queue.new
            Algorithm.get_all_algorithms_times.each do |experiment_id, next_execution_time|
              if next_execution_time <= Time.now
                work_queue.push(experiment_id)
              end
            end

            threads = (1..THREADS_NUMBER).map do
              Thread.new do
                until work_queue.empty?
                  execute_and_schedule(work_queue.pop)
                end
              end
            end

            threads.each &:join

            sleep(RUNNER_INTERVAL)
          end
        rescue => e
          LOGGER.error "Exception occurred during Algorithm Runner loop: #{e.to_s}\n#{e.backtrace.join("\n")}"
          raise
        end
      end
    end

    ##
    # Arguments:
    #  * experiment_id - id of experiment which algorithm should be executed
    # Executes decision loop of Algorithm, then schedules next execution
    # Algorithm is destroyed when Experiment is completed
    def self.execute_and_schedule(experiment_id)
      begin
        Scalarm::MongoLock.try_mutex("experiment-#{experiment_id}-workers-scaling") do
          experiment = Experiment.find_by_id(experiment_id)
          algorithm = AlgorithmFactory.get_algorithm(experiment_id)

          if experiment.nil? or experiment.completed?
            algorithm.destroy
            LOGGER.debug 'Experiment is completed, destroying algorithm record'
          else
            LOGGER.debug 'Starting experiment_status_check method'
            algorithm.experiment_status_check
            algorithm.update_next_execution_time
            LOGGER.debug "Setting next execution time to #{algorithm.next_execution_time.inspect}"
          end
        end
      rescue => e
        LOGGER.error "Exception occurred during workers scaling algorithm: #{e.to_s}\n#{e.backtrace.join("\n")}"
        raise
      end
    end

  end
end
