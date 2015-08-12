##
# Scheduler to run scaling algorithm decision loop periodically
class AlgorithmRunner

  ##
  # Expects:
  # * instance of scaling algorithm
  # * interval between decision loop executions in seconds
  def initialize(algorithm, interval)
    @algorithm = algorithm
    @interval = interval
  end

  ##
  # Initializes algorithm, then runs its decision loop periodically every <@interval> seconds
  # Stops after receiving false return value from decision loop
  def start
    @algorithm.send(:initial_deployment)

    loop do
      sleep @interval if @algorithm.send(:experiment_status_check)
    end
  end

end