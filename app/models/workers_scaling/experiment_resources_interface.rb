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
    # Schedules given amount of workers onto infrastructure and returns theirs sm_uuids
    # In case of error returns nil
    # Additional params:
    # * time_limit
    # * proxy
    # Raises InfrastructureError
    def schedule_workers(amount, infrastructure_name, params = {})
      begin
        #TODO to_s, to_sym
        params['time_limit'] = 60 if params['time_limit'].nil?
        params.merge! onsite_monitoring: true
        get_facade_for(infrastructure_name)
          .start_simulation_managers(@user_id, amount, @experiment_id, params)
          .map &:sm_uuid
      rescue InvalidCredentialsError, NoCredentialsError
        # TODO inform user about credentials error
        raise
      end
    end

    ##
    # Returns list of available infrastructures for experiment
    def get_available_infrastructures
      InfrastructureFacadeFactory.list_infrastructures(@user_id)
          .flat_map {|x| x.has_key?(:children) ? x[:children] : x }
          .select {|x| x[:enabled]}
          .map {|x| x[:infrastructure_name].to_sym}
    end

    ##
    # Returns statistics about available infrastructure:
    #   * workers_count
    # params:
    #   * infrastructure_names
    # Raises InfrastructureError
    def get_infrastructures_statistics(params = {})
      infrastructure_names = params[:infrastructure_names] || get_available_infrastructures
      infrastructure_names.map {|name| [name, get_infrastructure_statistics(name, params)]}.to_h
    end

    ##
    # Returns statistics about given infrastructure, statistics description in #get_infrastructures_statistics
    # Raises InfrastructureError
    def get_infrastructure_statistics(infrastructure_name, params = {})
      {
          workers_count: get_facade_for(infrastructure_name).sm_record_class
                             .where({user_id: @user_id, experiment_id: @experiment_id}).count
      }
    end

    ##
    # Returns workers records per infrastructure
    # params:
    #   * infrastructure_names
    #   * opts
    #   * cond
    # Possible cond and opts can be found in MongoActiveRecord#where.
    # Raises InfrastructureError
    def get_workers_records(params = {})
      cond = {experiment_id: @experiment_id, user_id: @user_id}
      cond.merge params[:cond] if params.has_key? :cond
      opts = {}
      opts.merge params[:opts] if params.has_key? :opts
      facades = params[:infrastructure_names] || get_available_infrastructures
      facades.map {|name| [name, get_facade_for(name).sm_record_class.where(cond, opts).to_a]}
          .flat_map {|name, records| records.map { |record| record.infrastructure=name; record }}
    end

    ##
    # Yields workers for given records
    # Usage:
    #   yield_workers(records) do |worker|
    #      worker.<some method>
    #   end
    # Workers commands: restart, stop, destroy_record
    # Raises InfrastructureError
    def yield_workers(records)
      records.each do |record|
        get_facade_for(record.infrastructure).yield_simulation_manager(record) {|worker| yield worker}
      end
    end

    private

    def get_facade_for(infrastructure_name)
      # TODO throw exception about disallowed infrastructures
      unless @facades_cache.has_key? infrastructure_name
        throw NoSuchInfrastructureError unless get_available_infrastructures.include? infrastructure_name
        @facades_cache[infrastructure_name] = InfrastructureFacadeFactory.get_facade_for infrastructure_name
      end
      @facades_cache[infrastructure_name]
    end
  end

end
