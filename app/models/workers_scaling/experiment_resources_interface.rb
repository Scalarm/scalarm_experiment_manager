require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'
include InfrastructureErrors
##
# Experiment interface to schedule and maintain computational resources
module WorkersScaling
  class ExperimentResourcesInterface

    def initialize(experiment_id, user_id)
      # TODO list if disallowed infrastructures
      @experiment_id = experiment_id.to_s
      @user_id = BSON::ObjectId(user_id.to_s)
      @facades_cache = {}
    end

    ##
    # Returns list of available infrastructure configurations for experiment
    # Infrastructure configuration format: {name: <name>, params: {<params>}}
    # <params> may include e.g. credentials_id for private_machine
    def get_available_infrastructures
      InfrastructureFacadeFactory.list_infrastructures(@user_id)
          .flat_map {|x| x.has_key?(:children) ? x[:children] : x }
          .select {|x| x[:enabled]}
          .map {|x| x[:infrastructure_name].to_sym}
          .map do |infrastructure_name|
        InfrastructureFacadeFactory.get_facade_for(infrastructure_name).get_subinfrastructures(@user_id)
      end.flatten
    end

    ##
    # Schedules given amount of workers onto infrastructure and returns theirs sm_uuids
    # In case of error returns nil
    # Additional params:
    # * time_limit
    # * proxy
    # Raises InfrastructureError
    def schedule_workers(amount, infrastructure, params = {})
      begin
        params[:time_limit] = 60 if params[:time_limit].nil?
        params.merge! onsite_monitoring: true
        params.merge! infrastructure[:params]

        # TODO: SCAL-1024 - facades use both string and symbol keys
        params = params.symbolize_keys.merge(params.stringify_keys)

        get_facade_for(infrastructure[:name])
          .start_simulation_managers(@user_id, amount, @experiment_id, params)
          .map &:sm_uuid
      rescue InvalidCredentialsError, NoCredentialsError
        # TODO inform user about credentials error
        raise
      end
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
    # Returns list of workers records for infrastructure
    def get_workers_records_list(infrastructure, params = {})
      get_workers_records_cursor(infrastructure, params).to_a
    end

    ##
    # Returns workers records count for infrastructure
    def get_workers_records_count(infrastructure, params = {})
      get_workers_records_cursor(infrastructure, params).count
    end

    ##
    # Returns worker record for given sm_uuid
    def get_worker_record_by_sm_uuid(sm_uuid)
      get_available_infrastructures.map do |infrastructure|
        get_workers_records_cursor(infrastructure, cond: {sm_uuid: sm_uuid}).first
      end .flatten.first
    end

    ##
    # Yields workers for given records
    # Usage:
    #   yield_workers(records) do |worker|
    #      worker.<some method>
    #   end
    # Workers commands: restart, stop, destroy_record
    def yield_workers(records)
      records.each do |record|
        get_facade_for(record.infrastructure).yield_simulation_manager(record) {|worker| yield worker}
      end
    end

    private

    ##
    # Returns InfrastructureFacade for given infrastructure name
    # Previously accessed facades are cached
    def get_facade_for(infrastructure_name)
      # TODO throw exception about disallowed infrastructures
      unless @facades_cache.has_key? infrastructure_name
        throw NoSuchInfrastructureError unless get_available_infrastructures.map {|infrastructure| infrastructure[:name]}
                                                                            .include? infrastructure_name
        @facades_cache[infrastructure_name] = InfrastructureFacadeFactory.get_facade_for infrastructure_name
      end
      @facades_cache[infrastructure_name]
    end

    ##
    # Returns Mongo cursor for given query
    # Arguments:
    # * infrastructure - hash with infrastructure info
    # * params:
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    def get_workers_records_cursor(infrastructure, params = {})
      cond = {experiment_id: @experiment_id, user_id: @user_id}
      cond.merge! params[:cond] if params.has_key? :cond
      cond.merge! infrastructure[:params]
      opts = {}
      opts.merge! params[:opts] if params.has_key? :opts

      get_facade_for(infrastructure[:name]).sm_record_class.where(cond, opts)
    end
  end

end
