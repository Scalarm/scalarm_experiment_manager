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
    # Params:
    # * experiment
    # * user_id
    # * allowed_infrastructures
    #     Variable storing user-defined workers limits for each infrastructure configuration
    #     Only infrastructures specified here can be used by experiment.
    #     Format: [{infrastructure: <infrastructure_configuration>, limit: <limit>}, ...]
    #     <infrastructure_configuration> - hash with infrastructure configuration
    #     <limit> - integer
    def initialize(experiment, user_id, allowed_infrastructures)
      @experiment = experiment
      @user_id = BSON::ObjectId(user_id.to_s)
      @facades_cache = {}
      @allowed_infrastructures = allowed_infrastructures.map {|x| ActiveSupport::HashWithIndifferentAccess.new(x)}
    end

    ##
    # Returns list of enabled infrastructure configurations for experiment
    # Infrastructure configuration format: {name: <name>, params: {<params>}}
    def get_enabled_infrastructures
      InfrastructureFacadeFactory.list_infrastructures(@user_id)
          .flat_map {|inf| inf.has_key?(:children) ? inf[:children] : inf }
          .select {|inf| inf[:enabled]}
          .map do |inf|
            ActiveSupport::HashWithIndifferentAccess.new({name: inf[:infrastructure_name].to_sym, params: {}})
          end
    end

    ##
    # Returns list of available infrastructure configurations for experiment
    # Infrastructure configuration format: {name: <name>, params: {<params>}}
    # Infrastructures with to many workers in error state will be omitted
    # <params> may include e.g. credentials_id for private_machine
    def get_available_infrastructures
      enabled_infrastructures = get_enabled_infrastructures
      @allowed_infrastructures
          .select do |allowed|
            !!enabled_infrastructures.detect {|enabled| infrastructure_configs_equal?(enabled, allowed[:infrastructure])}
          end
          .map{|entry| entry[:infrastructure]}
          .select {|inf| not infrastructure_not_working?(inf)}
    end

    ##
    # Returns amount of Workers that can be yet scheduled on given infrastructure_configuration
    def current_infrastructure_limit(infrastructure_configuration)
      infrastructure_limit = @allowed_infrastructures.detect do |entry|
        infrastructure_configs_equal?(infrastructure_configuration, entry[:infrastructure])
      end
      if infrastructure_limit.nil?
        0
      else
        [0, infrastructure_limit[:limit] - get_workers_records_count(infrastructure_configuration,
          cond: Query::Workers::NOT_ERROR)].max
      end
    end

    ##
    # Schedules workers on infrastructure
    # Number of workers scheduled may be lesser than <amount>, see #calculate_needed_workers
    # @param amount [Fixnum]
    # @param infrastructure_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @return [Array<Symbol>] sm_uuids of started workers
    # @raise [InfrastructureError] if #start_simulation_managers method fails
    #   or infrastructure_configuration not allowed
    def schedule_workers(amount, infrastructure_configuration)
      raise AccessDeniedError unless @allowed_infrastructures.detect do |allowed|
        infrastructure_configs_equal?(infrastructure_configuration, allowed[:infrastructure], true)
      end
      return [] if infrastructure_not_working?(infrastructure_configuration)

      real_amount, already_scheduled_workers = calculate_needed_workers(amount, infrastructure_configuration)
      return already_scheduled_workers if real_amount <= 0
      # TODO: SCAL-1189
      infrastructure_configuration[:params][:time_limit] = 60 if infrastructure_configuration[:params][:time_limit].nil?
      get_facade_for(infrastructure_configuration[:name])
        .start_simulation_managers(@user_id, real_amount, @experiment.id.to_s, infrastructure_configuration[:params])
        .map(&:sm_uuid)
        .concat(already_scheduled_workers)
    end

    ##
    # Marks worker with given sm_uuid to be deleted after finishing given number of simulations
    # If overwrite is set to false, worker will not be marked if simulations_left field is already set,
    # otherwise new number will be set in all cases
    # Using overwrite=true may result in unintentional resetting simulations_left field,
    # effectively prolonging lifetime of worker, therefore default value is false
    def limit_worker_simulations(sm_uuid, simulations_left, overwrite=false)
      worker = get_worker_record_by_sm_uuid(sm_uuid)
      unless worker.nil?
        worker.simulations_left = simulations_left if worker.simulations_left.blank? or overwrite
        worker.save
      end
    end

    ##
    # Stops worker after completing its current simulation execution
    def soft_stop_worker(sm_uuid)
      limit_worker_simulations(sm_uuid, 1)
    end

    ##
    # Returns list of workers records for infrastructure_configuration
    def get_workers_records_list(infrastructure_configuration, params = {})
      get_workers_records_cursor(infrastructure_configuration, params).to_a
    end

    ##
    # Returns workers records count for infrastructure_configuration
    def get_workers_records_count(infrastructure_configuration, params = {})
      get_workers_records_cursor(infrastructure_configuration, params).count
    end

    ##
    # Returns overall Workers count for Experiment matching given params
    def count_all_workers(params = {})
      get_enabled_infrastructures
          .flat_map { |infrastructure| get_workers_records_count(infrastructure, params) }
          .reduce(0) { |sum, count| sum + count }
    end

    ##
    # Returns worker record for given sm_uuid
    def get_worker_record_by_sm_uuid(sm_uuid)
      get_enabled_infrastructures.map do |infrastructure|
        get_workers_records_cursor(infrastructure, cond: {sm_uuid: sm_uuid}).first
      end .detect { |worker| not worker.nil? }
    end

    private

    ##
    # Parses requested amount of workers to schedule to real amount.
    # Already starting and initializing workers are taken into consideration.
    # Amount to start is limited by imposed restriction and not simulation to run number.
    # @param requested_amount [Fixnum]
    # @param infrastructure_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @return [Fixnum] real needed amount
    # @return [Array<Symbol>] list of sm_uuids of already scheduled workers
    def calculate_needed_workers(requested_amount, infrastructure_configuration)
      @experiment.reload
      starting_workers = get_workers_records_list(
          infrastructure_configuration, cond: Query::Workers::RUNNING_WITHOUT_FINISHED_SIMULATIONS).map(&:sm_uuid)
      initializing_workers = get_workers_records_list(
          infrastructure_configuration, cond: Query::Workers::INITIALIZING).map(&:sm_uuid)

      # amount includes workers that do not count towards throughput yet, algorithm has no knowledge about them
      requested_amount -= starting_workers.count + initializing_workers.count
      # initializing workers have not yet taken simulations, need to avoid scheduling workers that will not get one
      simulations_left = @experiment.count_simulations_to_run - initializing_workers.count

      real_amount = [requested_amount, current_infrastructure_limit(infrastructure_configuration), simulations_left].min
      return real_amount, starting_workers + initializing_workers
    end

    ##
    # Checks whether infrastructure works by checking number of workers in error state
    # @param infrastructure_configuration [ActiveSupport::HashWithIndifferentAccess]
    # @return [true, false]
    def infrastructure_not_working?(infrastructure_configuration)
      get_workers_records_count(infrastructure_configuration, Query::Workers::ERROR) > MAXIMUM_NUMBER_OF_FAILED_WORKERS
    end

    ##
    # Checks whether all fields from narrower are equal with corresponding fields from wider
    # when exact flag is set to false. Performs full comparison when exact flag is true.
    # By default exact flag is set to false
    # Returns true when infrastructure configurations are equal, false otherwise.
    def infrastructure_configs_equal?(narrower, wider, exact=false)
      # TODO replace with infrastructure id
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
    # Returns InfrastructureFacade for given infrastructure name
    # Previously accessed facades are cached
    def get_facade_for(infrastructure_name)
      unless @facades_cache.has_key? infrastructure_name
        throw NoSuchInfrastructureError unless get_enabled_infrastructures.map {|infrastructure| infrastructure[:name]}
                                                                            .include? infrastructure_name
        @facades_cache[infrastructure_name] = InfrastructureFacadeFactory.get_facade_for infrastructure_name
      end
      @facades_cache[infrastructure_name]
    end

    ##
    # Returns Mongo cursor for given query
    # Arguments:
    # * infrastructure_configuration - hash with infrastructure configuration
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    def get_workers_records_cursor(infrastructure_configuration, params = {})
      get_facade_for(infrastructure_configuration[:name])
        .query_simulation_manager_records(@user_id, @experiment.id.to_s, infrastructure_configuration[:params])
        .where(
            params[:cond] || ActiveSupport::HashWithIndifferentAccess.new,
            params[:opts] || ActiveSupport::HashWithIndifferentAccess.new
        )
    end
  end

end
