require 'workers_scaling/utils/logger'
module WorkersScaling
  ##
  # Scheduler to run Algorithm decision loop periodically
  class AlgorithmRunner

    RUNNER_INTERVAL = 15.seconds
    THREADS_NUMBER = 4

    ##
    # Firstly initializes threads
    # Then runs periodically and calls runner_loop
    def self.start
      Thread.new do
        begin
          work_queue = Queue.new
          initialize_threads(work_queue)

          loop do
            runner_loop(work_queue)
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
    #  * work_queue - queue with next algorithms to be executed
    # Starts THREADS_NUMBER threads, each running in loop
    # and calling execute_and_schedule for next experiment_id from queue
    # Returns list of started threads
    def self.initialize_threads(work_queue)
      LOGGER.debug 'Starting Algorithm Runner worker threads'
      (1..THREADS_NUMBER).map do
        Thread.new do
          loop do
            begin
              execute_and_schedule(work_queue.pop)
            rescue => e
              LOGGER.error "Worker thread encountered exception: #{e.to_s}\nWill continue working"
            end
          end
        end
      end
    end

    ##
    # Arguments:
    #  * work_queue - queue for scheduling next algorithms for execution
    # Gets from database all algorithms ready to be executed
    # Enqueues them to be executed by threads
    # Waits until all are taken from queue for execution
    def self.runner_loop(work_queue)
      LOGGER.debug 'Entering Algorithm Runner loop'
      AlgorithmFactory.get_experiment_ids_for_ready_algorithms.each do |experiment_id|
        work_queue.push(experiment_id)
      end

      # wait for all algorithms completion
      sleep 0.5 until work_queue.empty?
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

          if experiment.nil? or experiment.completed? or not experiment.is_running
            algorithm.destroy
            LOGGER.debug 'Experiment is not running, destroying algorithm record'
          else
            LOGGER.debug 'Starting execute_algorithm_step method'
            algorithm.execute_algorithm_step
            algorithm.notify_execution
            LOGGER.debug "Setting next execution time to #{algorithm.next_execution_time.inspect}"
          end
        end
      rescue => e
        LOGGER.error "Exception occurred during workers scaling algorithm: #{e.to_s}\n#{e.backtrace.join("\n")}"
        AlgorithmFactory.get_algorithm(experiment_id).notify_error
        raise
      end
    end

  end
end
