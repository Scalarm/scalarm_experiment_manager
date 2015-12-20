require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'
require 'workers_scaling/utils/query'
include InfrastructureErrors
module WorkersScaling
  ##
  # Experiment interface to schedule and maintain computational resources
  class ExperimentResourcesInterface
    MAXIMUM_NUMBER_OF_FAILED_WORKERS = 3

    ##
    # @param experiment [Experiment]
    # @param user_id [BSON::ObjectId, String]
    # @param allowed_resource_configurations [Array<Hash, ActiveSupport::HashWithIndifferentAccess>]
    #   Variable storing user-defined workers limits for each resource configuration
    #   Only resource configuration specified here can be used by experiment.
    #   Format: [{resource_configuration: <resource_configuration>, limit: <limit>}, ...]
    #     <resource_configuration> - hash with resource configuration
    #     <limit> - Fixnum
    def initialize(experiment, user_id, allowed_resource_configurations)
      @experiment = experiment
      @user_id = BSON::ObjectId(user_id.to_s)
      @facades_cache = {}
      @allowed_resource_configurations = allowed_resource_configurations.map do |x|
        ActiveSupport::HashWithIndifferentAccess.new(x)
      end
    end

    ##
    # Returns list of enabled resource configurations for experiment
    # Resource configuration format: {name: <name>, params: {<params>}}
    # @return [Arrat<ActiveSupport::HashWithIndifferentAccess>] list of enabled resource configurations
    def get_enabled_resource_configurations
      InfrastructureFacadeFactory.get_all_infrastructures
          .select { |inf| inf.enabled_for_user?(@user_id) }
          .map { |inf| ActiveSupport::HashWithIndifferentAccess.new({name: inf.short_name.to_sym, params: {}}) }
    end

    ##
    # Returns list of available resource configurations for experiment
    # Resource configuration format: {name: <name>, params: {<params>}}
    # Resource configuration with too many workers in error state will be omitted
    # <params> may include e.g. credentials_id for private_machine
    # @return [Arrat<ActiveSupport::HashWithIndifferentAccess>] list of available resource configurations
    def get_available_resource_configurations
      enabled_resource_configurations = get_enabled_resource_configurations
      @allowed_resource_configurations
          .select do |allowed|
            !!enabled_resource_configurations.detect do |enabled|
              resource_configurations_equal?(enabled, allowed[:resource_configuration])
            end
          end
          .map{|entry| entry[:resource_configuration]}
          .select {|inf| not resource_configuration_not_working?(inf)}
    end

    ##
    # Returns amount of workers that can be yet scheduled using resource_configuration
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @return [Fixnum] current resource_configuration workers limit
    def current_resource_configuration_limit(resource_configuration)
      allowed_configurations_entry = @allowed_resource_configurations.detect do |entry|
        resource_configurations_equal?(resource_configuration, entry[:resource_configuration])
      end
      if allowed_configurations_entry.nil?
        0
      else
        [0, allowed_configurations_entry[:limit] - get_workers_records_count(resource_configuration,
          cond: Query::Workers::NOT_ERROR)].max
      end
    end

    ##
    # Schedules workers on resource configuration
    # Amount of workers scheduled may be lesser than <amount>, see #calculate_needed_workers
    # @param amount [Fixnum] amount of workers to start
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @return [Array<String>] sm_uuids of started workers
    # @raise [InfrastructureErrors::AccessDeniedError] if resource_configuration not allowed
    # @raise [InfrastructureErrors::InfrastructureError] if #start_simulation_managers method fails
    def schedule_workers(amount, resource_configuration)
      raise AccessDeniedError unless @allowed_resource_configurations.detect do |allowed|
        resource_configurations_equal?(resource_configuration, allowed[:resource_configuration], true)
      end
      return [] if resource_configuration_not_working?(resource_configuration)

      real_amount, already_scheduled_workers = calculate_needed_workers(amount, resource_configuration)
      return already_scheduled_workers if real_amount <= 0

      get_facade_for(resource_configuration[:name])
        .start_simulation_managers(@user_id, real_amount, @experiment.id.to_s, resource_configuration[:params])
        .map(&:sm_uuid)
        .concat(already_scheduled_workers)
    end

    ##
    # Marks worker with given sm_uuid to be deleted after finishing given number of simulations
    # Using overwrite=true may result in unintentional resetting simulations_left field,
    # effectively prolonging lifetime of worker, therefore default value is false
    # @param sm_uuid [String] worker sm_uuid
    # @param simulations_left [Fixnum] number of simulation left to execute by worker 
    # @param overwrite [true, false] if set to false, simulations_left will not be updated if already set
    def limit_worker_simulations(sm_uuid, simulations_left, overwrite=false)
      worker = get_worker_record_by_sm_uuid(sm_uuid)
      unless worker.nil?
        worker.simulations_left = simulations_left if worker.simulations_left.blank? or overwrite
        worker.save
      end
    end

    ##
    # Stops worker after completing its current simulation execution
    # @param sm_uuid [String] worker sm_uuid
    def soft_stop_worker(sm_uuid)
      limit_worker_simulations(sm_uuid, 1)
    end

    ##
    # Returns list of workers records for resource_configuration
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions 
    # @option params [Hash] :opts query options
    # @return [Array<PrivateMachineRecord, PlGridJob, CloudVmRecord, DummyRecord>] workers records
    def get_workers_records_list(resource_configuration, params = {})
      get_workers_records_cursor(resource_configuration, params).to_a
    end

    ##
    # Returns workers records count for resource_configuration
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions
    # @option params [Hash] :opts query options
    # @return [Fixnum] workers records count
    def get_workers_records_count(resource_configuration, params = {})
      get_workers_records_cursor(resource_configuration, params).count
    end

    ##
    # Returns overall workers count for Experiment matching given params
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions
    # @option params [Hash] :opts query options
    # @return [Fixnum] workers records count
    def count_all_workers(params = {})
      get_enabled_resource_configurations
          .flat_map { |configuration| get_workers_records_count(configuration, params) }
          .reduce(0) { |sum, count| sum + count }
    end

    ##
    # Returns worker record for given sm_uuid
    # @param sm_uuid [String] worker sm_uuid
    # @return [PrivateMachineRecord, PlGridJob, CloudVmRecord, DummyRecord] worker record
    def get_worker_record_by_sm_uuid(sm_uuid)
      get_enabled_resource_configurations.map do |configuration|
        get_workers_records_cursor(configuration, cond: {sm_uuid: sm_uuid}).first
      end .detect { |worker| not worker.nil? }
    end

    private

    ##
    # Adjusts requested amount of workers.
    # Amount to start is limited by imposed restriction and number of simulations to run.
    # Already starting and initializing workers are taken into consideration.
    # @param requested_amount [Fixnum]
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @return [Fixnum] real needed amount
    # @return [Array<String>] list of sm_uuids of already scheduled workers
    def calculate_needed_workers(requested_amount, resource_configuration)
      @experiment.reload
      starting_workers = get_workers_records_list(
          resource_configuration, cond: Query::Workers::RUNNING_WITHOUT_FINISHED_SIMULATIONS).map(&:sm_uuid)
      initializing_workers = get_workers_records_list(
          resource_configuration, cond: Query::Workers::INITIALIZING).map(&:sm_uuid)

      # amount includes workers that do not count towards throughput yet, algorithm has no knowledge about them
      requested_amount -= starting_workers.count + initializing_workers.count
      # initializing workers have not yet taken simulations, need to avoid scheduling workers that will not get one
      simulations_left = @experiment.count_simulations_to_run - initializing_workers.count

      real_amount = [requested_amount, current_resource_configuration_limit(resource_configuration), simulations_left].min
      return real_amount, starting_workers + initializing_workers
    end

    ##
    # Checks whether resource configuration works by checking number of workers in error state
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @return [true, false]
    def resource_configuration_not_working?(resource_configuration)
      get_workers_records_count(resource_configuration, Query::Workers::ERROR) > MAXIMUM_NUMBER_OF_FAILED_WORKERS
    end

    ##
    # Checks whether all fields from narrower are equal with corresponding fields from wider
    # when exact flag is set to false. Performs full comparison when exact flag is true.
    # Returns true when resource configurations are equal, false otherwise.
    # @param narrower [ActiveSupport::HashWithIndifferentAccess] resource configuration
    # @param wider [ActiveSupport::HashWithIndifferentAccess] resource configuration
    # @param exact [true, false] specifies whether compares all fields or only from narrower
    # @return [true, false] comparison result
    def resource_configurations_equal?(narrower, wider, exact=false)
      return false if wider[:name] != narrower[:name]
      if exact
        return false if wider[:params] != narrower[:params]
      else
        narrower[:params].each do |key, value|
          return false if wider[:params][key] != value
        end
      end
      true
    end

    ##
    # Returns InfrastructureFacade for given infrastructure name, previously accessed facades are cached
    # @param infrastructure_name [Symbol]
    # @return [PrivateMachineFacade, PlGridFacade, CloudFacade, DummyFacade] infrastructure facade
    def get_facade_for(infrastructure_name)
      unless @facades_cache.has_key? infrastructure_name
        @facades_cache[infrastructure_name] = InfrastructureFacadeFactory.get_facade_for infrastructure_name
      end
      @facades_cache[infrastructure_name]
    end

    ##
    # Returns Mongo cursor for given query
    # @param resource_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @param params [Hash] optional parameters for database query, for details see MongoActiveRecord#where
    # @option params [Hash] :cond query conditions
    # @option params [Hash] :opts query options
    # @return [MongoActiveRecord] cursor for workers record mongo collection
    def get_workers_records_cursor(resource_configuration, params = {})
      get_facade_for(resource_configuration[:name])
        .query_simulation_manager_records(@user_id, @experiment.id.to_s, resource_configuration[:params])
        .where(params[:cond] || {}, params[:opts] || {})
    end
  end

end
