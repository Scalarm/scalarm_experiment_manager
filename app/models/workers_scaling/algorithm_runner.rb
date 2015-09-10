##
# Scheduler to run Algorithm decision loop periodically
module WorkersScaling
  class AlgorithmRunner
    @@cache = {}

    ##
    # Returns instance of AlgorithmRunner for experiment_id if registered
    # Otherwise returns nil
    def self.get(experiment_id)
      return @@cache[experiment_id] if @@cache
    end

    ##
    # Registers instance of AlgorithmRunner for experiment_id
    def self.put(experiment_id, runner)
      @@cache[experiment_id] = runner
    end

    ##
    # Unregisters instance of AlgorithmRunner for experiment_id
    def self.delete(experiment_id)
      @@cache.delete(experiment_id) if @@cache
    end

    ##
    # Expects:
    # * instance of Experiment
    # * instance of Algorithm for given Experiment
    # * interval between decision loop executions in seconds
    def initialize(experiment, algorithm, interval)
      @experiment = experiment
      @algorithm = algorithm
      @interval = interval
      @mutex = Mutex.new

      self.class.put(@experiment.id, self)
    end

    ##
    # Initializes Algorithm, then starts its decision loop
    # Stops when there is no next execution time set
    def start
      Thread.new do
        @algorithm.initial_deployment
        @next_execution_time = Time.now + @interval

        @mutex.synchronize do
          catch :finished do
            until @next_execution_time.nil?

              while @next_execution_time > Time.now do
                @mutex.sleep @next_execution_time - Time.now
                throw :finished if @next_execution_time.nil?
              end

              execute_and_schedule
            end
          end
        end

        self.class.delete(@experiment.id)
      end
    end

    ##
    # Executes decision loop of Algorithm, then schedules next execution
    # Next execution time is not set when Experiment is completed
    def execute_and_schedule
      should_unlock = false
      unless @mutex.owned?
        @mutex.lock
        should_unlock = true
      end

      @algorithm.experiment_status_check

      @next_execution_time = if @experiment.reload.completed?
                               nil
                             else
                               Time.now + @interval
                             end

      @mutex.unlock if should_unlock
    end

  end
end
