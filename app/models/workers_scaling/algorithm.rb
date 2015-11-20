require_relative 'experiment_resources_interface'
require_relative 'experiment_statistics'
module WorkersScaling
  ##
  # Class describing interface of Workers scaling algorithm. Creating new algorithm
  # requires providing class with proper methods implemented, which also should
  # inherit Algorithm class.
  class Algorithm < Scalarm::Database::MongoActiveRecord
    use_collection 'workers_scaling_algorithms'
    attr_accessor :experiment
    attr_accessor :resources_interface
    attr_accessor :experiment_statistics

    NOT_IMPLEMENTED = 'This is an abstract method, which must be implemented by all subclasses'
    ALGORITHM_INTERVAL = 30.seconds

    ##
    # Returns name of Algorithm implementation class
    def self.get_class_name
      self.name.gsub('::', '__').underscore.to_sym
    end

    ##
    # Finds all records of Algorithm implementations
    # Returns hash containing {experiment_id => next_execution_time} pair for each record
    def self.get_all_algorithms_times
      self.where({}, {fields: [:experiment_id, :next_execution_time]}).map do |record|
        [record.experiment_id, record.next_execution_time]
      end .to_h
    end

    ##
    # Arguments: attributes hash containing fields:
    #  * experiment_id - id of Experiment
    #  * user_id - id of User starting Algorithm
    #  * allowed_infrastructures - list of hashes with infrastructure and maximal Workers amount
    #      (Detailed description at ExperimentResourcesInterface#initialize)
    #  * planned_finish_time - desired time of end of Experiment (as Time instance)
    #  * last_update_time - time of last change of user-defined fields (allowed_infrastructures, planned_finish_time)
    #  * params (optional) - additional params, currently unused, may be used in subclasses
    # All these fields are available in any Algorithm as if attr_accessor was created for each of them
    def initialize(attributes)
      super(attributes)
    end

    ##
    # Must be executed before running #initial_deployment or #experiment_status_check
    # Initializes fields that are not stored in database:
    #  * @experiment
    #  * @resources_interface
    #  * @experiment_statistics
    # Returns self to allow chaining
    def initialize_runtime_fields
      @experiment = Experiment.find_by_id(experiment_id)
      @resources_interface = ExperimentResourcesInterface.new(@experiment, user_id, allowed_infrastructures)
      @experiment_statistics = ExperimentStatistics.new(@experiment, @resources_interface)
      self
    end

    def save
      self.class_name = self.class.get_class_name
      super
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

    def update_next_execution_time
      self.next_execution_time = Time.now + ALGORITHM_INTERVAL
      save
    end

  end
end