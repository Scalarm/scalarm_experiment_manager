##
# Scheduler to run WorkersScalingAlgorithm decision loop periodically
class WorkersScalingAlgorithmRunner

  ##
  # Expects:
  # * instance of Experiment
  # * instance of WorkersScalingAlgorithm for given Experiment
  # * interval between decision loop executions in seconds
  def initialize(experiment, algorithm, interval)
    @experiment = experiment
    @algorithm = algorithm
    @interval = interval
  end

  ##
  # Initializes WorkersScalingAlgorithm, then starts its decision loop
  # Stops when there is no next execution time set
  def start
    Thread.new do
      @algorithm.initial_deployment
      @next_execution_time = Time.now + interval

      until @next_execution_time.nil?

        while @next_execution_time > Time.now do
          sleep @next_execution_time - Time.now
        end

        execute_and_schedule
      end
    end
  end

  ##
  # Executes decision loop of WorkersScalingAlgorithm, then schedules next execution
  # Next execution time is not set when Experiment is completed
  def execute_and_schedule
    @algorithm.experiment_status_check

    @next_execution_time = if @experiment.reload.completed?
                             nil
                           else
                             Time.now + @interval
                           end
  end

end