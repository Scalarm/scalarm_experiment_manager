require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

##
# Experiment API to schedule and maintenance computational resources
module ResourcesAPI

  ##
  # Schedules given amount of workers onto infrastructure and returns theirs ids
  # In case of error returns nil
  # Additional params:
  # * time_limit
  # * proxy
  def schedule_workers(amount, infrastructure_name, params = {})
    begin
      params['time_limit'] = 60 if params['time_limit'].nil?
      InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
        .start_simulation_managers(user_id, amount, experiment_id, params)
        .map {|r| r.id.to_s}
    rescue InfrastructureErrors::NoSuchInfrastructureError, InfrastructureErrors::ScheduleError,
        InfrastructureErrors::NoCredentialsError, InfrastructureErrors::InvalidCredentialsError
      return nil
    end
  end

  ##
  # Schedules one worker onto infrastructure and returns its id
  # In case of error returns nil
  # Additional params listed in #schedule_workers
  def schedule_worker(infrastructure_name, params = {})
    schedule_workers(1, infrastructure_name, params).first
  end

  ##
  # Returns list of available infrastructures for experiment
  def get_infrastructures_list
    InfrastructureFacadeFactory.list_infrastructures(user_id)
        .map {|x| x.has_key?(:children) ? x[:children] : x }.flatten
        .select {|x| x[:enabled]}
        .map {|x| x[:infrastructure_name]}
  end

  ##
  # Returns statistics about available infrastructures
  # Statistics description is in #get_infrastructure_statistics
  def get_infrastructures_statistics(params = {})
    Hash[map_available_infrastructures method(:get_infrastructure_statistics), params]
  end

  ##
  # Returns statistics about given infrastructure:
  # * workers_count
  def get_infrastructure_statistics(infrastructure_name, params = {})
    {
        workers_count: InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
                           .count_sm_records(user_id, experiment_id)
                           # TODO this loads all sm records form db
    }
  end

  ##
  # Returns workers records for all available infrastructures
  def get_all_workers_records(params = {})
    Hash[map_available_infrastructures method(:get_workers_records), params]
  end

  ##
  # Returns workers records for given infrastructure
  def get_workers_records(infrastructure_name, params = {})
    # TODO load from db only specific parameters
    InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
        .get_sm_records(user_id, experiment_id, params) || []
  end

  ##
  # Returns worker record for given id and infrastructure
  def get_worker_record(id, infrastructure_name, params = {})
    # TODO load from db only specific parameters
    InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
        .get_sm_record_by_id(id)
  end

  ##
  # Returns workers records for all available infrastructures
  def get_all_workers(params = {})
    Hash[map_available_infrastructures method(:get_workers), params]
  end

  ##
  # Returns worker for given infrastructure
  def get_workers(infrastructure_name, params = {})
    InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
        .yield_simulation_managers(user_id, experiment_id, params) {|x| x}
  end

  ##
  # Returns worker for given id and infrastructure
  def get_worker(id, infrastructure_name, params = {})
    InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
        .yield_simulation_manager(get_worker_record(id, infrastructure_name)) {|x| x}
  end

  ##
  # Executes command on workers with on given infrastructure
  # Possible commands is in #execute_command_on_worker
  def execute_command_on_workers(infrastructure_name, command)
    nil unless %w(stop restart destroy_record).include? command
    get_workers(infrastructure_name).each {|x| x.send command}
  end

  ##
  # Executes command on worker with given id and infrastructure
  # Possible commands: 'stop', 'destroy_record', 'restart'
  def execute_command_on_worker(id, infrastructure_name, command)
    nil unless %w(stop restart destroy_record).include? command
    get_worker(id, infrastructure_name).sens command
  end

  private
  def map_available_infrastructures(func, params = {})
    get_infrastructures_list.map {|name| [name, func.call(name, params)]}
  end
end