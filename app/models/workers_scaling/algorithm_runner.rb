##
# Scheduler to run WorkersScalingAlgorithm decision loop periodically
module WorkersScaling
  class AlgorithmRunner

    ##
    # Returns instance of AlgorithmRunner for experiment_id if registered
    # Otherwise returns nil
    def self.get(experiment_id)
      return @@cache[experiment_id] if @@cache
    end

    ##
    # Registers instance of AlgorithmRunner for experiment_id
    def self.put(experiment_id, runner)
      @@cache ||= {}
      @@cache[experiment_id] = runner
    end

    ##
    # Unregisters instance of AlgorithmRunner for experiment_id
    def self.delete(experiment_id)
      @@cache.delete(experiment_id) if @@cache
    end

    ##
    # Expects:
    # * id of Experiment
    # * instance of WorkersScalingAlgorithm for given Experiment
    # * interval between decision loop executions in seconds
    def initialize(experiment_id, algorithm, interval)
      @experiment = Experiment.where(id: experiment_id).first
      @algorithm = algorithm
      @interval = interval
      @mutex = Mutex.new

      self.class.put(@experiment.id, self)
    end

    ##
    # Initializes WorkersScalingAlgorithm, then starts its decision loop
    # Stops when there is no next execution time set
    def start
      Thread.new do
        @algorithm.initial_deployment
        @next_execution_time = Time.now + @interval

        until @next_execution_time.nil?

          while @next_execution_time > Time.now do
            sleep @next_execution_time - Time.now
          end

          execute_and_schedule
        end

        self.class.delete(@experiment.id)
      end
    end

    ##
    # Executes decision loop of WorkersScalingAlgorithm, then schedules next execution
    # Next execution time is not set when Experiment is completed
    def execute_and_schedule
      @mutex.synchronize do
        @algorithm.experiment_status_check

        @next_execution_time = if @experiment.reload.completed?
                                 nil
                               else
                                 Time.now + @interval
                               end
      end
    end

  end
end
