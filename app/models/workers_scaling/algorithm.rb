##
# Class describing interface of Workers scaling algorithm. Creating new algorithm
# requires providing class with proper methods implemented, which also should
# inherit Algorithm class.
module WorkersScaling
  class Algorithm

    NOT_IMPLEMENTED = 'This is an abstract method, which must be implemented by all subclasses'

    ##
    # Arguments:
    # * experiment - instance of Experiment
    # * user_id - id of User starting Algorithm
    # * allowed_infrastructures - list of hashes with infrastructure and maximal Workers amount
    #     (Detailed description at ExperimentResourcesInterface#initialize)
    # * planned_finish_time - desired time of end of Experiment (as Time instance)
    # * params - additional params, currently unused, may be used in subclasses
    def initialize(experiment, user_id, allowed_infrastructures, planned_finish_time, params = {})
      @experiment = experiment
      @resources_interface = ExperimentResourcesInterface.new(@experiment, user_id, allowed_infrastructures)
      @experiment_statistics = ExperimentStatistics.new(@experiment, @resources_interface)
      @planned_finish_time = planned_finish_time
    end

    ##
    # Method called when algorithm is starting, before first execution of
    # #experiment_status_check. Should contain actions performed in the
    # beginning of algorithm e.g. sending first workers on infrastructure.
    def initial_deployment
      raise NOT_IMPLEMENTED
    end

    ##
    # Main algorithm loop, executed on specified event (e.g. finished simulation) or
    # when given time since last execution passed. Should contain main algorithm logic.
    def experiment_status_check
      raise NOT_IMPLEMENTED
    end

  end
end