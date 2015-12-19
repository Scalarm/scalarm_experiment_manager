require_relative 'experiment_resources_interface'
require_relative 'experiment_metrics'
module WorkersScaling
  ##
  # Class describing interface of Workers scaling algorithm. Creating new algorithm
  # requires providing class with proper methods implemented, which also should
  # inherit Algorithm class.
  # Methods to implement by subclasses:
  #  * #initial_deployment
  #  * #experiment_status_check
  #  * #self.algorithm_name
  #  * #self.description
  class Algorithm < Scalarm::Database::MongoActiveRecord
    use_collection 'workers_scaling_algorithms'
    attr_accessor :experiment
    attr_accessor :resources_interface
    attr_accessor :experiment_metrics

    NOT_IMPLEMENTED = 'This is an abstract method, which must be implemented by all subclasses'
    ERRORS_MAX = 3

    ##
    # Returns name of Algorithm implementation class
    def self.get_class_name
      self.name.gsub('::', '__').underscore.to_sym
    end

    ##
    # Arguments: attributes hash containing fields:
    #  * experiment_id - id of Experiment to be subjected to Algorithm
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
    #  * @experiment_metrics
    # Returns self to allow chaining
    def initialize_runtime_fields
      @experiment = Experiment.find_by_id(experiment_id)
      @resources_interface = ExperimentResourcesInterface.new(@experiment, user_id, allowed_infrastructures)
      @experiment_metrics = ExperimentMetrics.new(@experiment, @resources_interface)
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

    ##
    # Returns time to wait between subsequent invocations of #experiment_status_check method
    # May be overridden in subclasses
    def interval
      30.seconds
    end

    ##
    # Marks Algorithm record as executed successfully
    # Sets next_execution_time as interval from now
    # Zeroes errors_count
    def notify_execution
      self.next_execution_time = Time.now + interval
      self.errors_count = 0
      save
    end

    ##
    # Notifies error encountered during Algorithm execution
    # Increments errors_count
    # Destroys record if errors_count exceeds ERRORS_MAX
    def notify_error
      self.errors_count ||= 0
      self.errors_count += 1
      if self.errors_count > ERRORS_MAX
        destroy
      else
        save
      end
    end

    ##
    # Name of algorithm visible to user
    def self.algorithm_name
      raise NOT_IMPLEMENTED
    end

    ##
    # Description of algorithm visible to user
    def self.description
      raise NOT_IMPLEMENTED
    end

  end
end