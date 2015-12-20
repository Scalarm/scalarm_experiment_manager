require 'workers_scaling/utils/errors'
require 'workers_scaling/utils/logger'
module WorkersScaling
  Dir["#{File.dirname(__FILE__)}/algorithms/**/*.rb"].each { |file| require file }

  ##
  # Class responsible for listing available Algorithm implementations
  # and creating instances of them
  class AlgorithmFactory
    @cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 10.minutes)

    ##
    # Recursively gets all descendants of given parent class
    def self.get_descendants(parent, include_self = true)
      descendants = ObjectSpace.each_object(Class)
          .select { |klass| klass < parent }
          .flat_map { |klass| get_descendants(klass) }
      descendants << parent if include_self
      descendants
    end

    ALGORITHMS = self.get_descendants(Algorithm, false)
                     .map { |klass| [klass.get_class_name, klass] }
                     .to_h

    ##
    # Returns list representing all available Algorithm implementations in format:
    #   {id: <id>, name: <name>, description: <description>}
    def self.get_algorithms_list
      ALGORITHMS.map{|key, klass| {id: key, name: klass.algorithm_name, description: klass.description} }
    end

    ##
    # Finds all records of Algorithm implementations with next_execution_time before current time
    # Returns list of experiment_ids for each record found
    def self.get_experiment_ids_for_ready_algorithms
      WorkersScaling::Algorithm.where(
          {next_execution_time: {'$lte' => Time.now}},
          {fields: [:experiment_id]}
      ).map do |record|
        record.experiment_id
      end
    end

    ##
    # Arguments: attributes hash containing:
    #  * class_name - symbol representing Algorithm implementation
    #  * experiment_id,
    #  * user_id,
    #  * allowed_resource_configurations,
    #  * planned_finish_time,
    #  * last_update_time - standard attributes for Algorithms (see #Algorithm for details)
    #  * params (optional) - hash with additional parameters for specific Algorithm implementations
    # Returns new instance of Algorithm implementation for given name
    # Raises AlgorithmNameUnknown if given name is unknown
    # Raises AlgorithmParameterMissing if attributes required by Algorithm are not present
    def self.create_algorithm(attributes)
      attributes.symbolize_keys!
      validate_attributes(attributes)
      class_name = attributes[:class_name].to_sym
      raise AlgorithmNameUnknown.new unless ALGORITHMS.has_key? class_name
      ALGORITHMS[class_name].new(attributes).initialize_runtime_fields
    end

    ##
    # Returns instance of algorithm from cache
    # If Algorithm is not stored in cache, new one will be created
    # If stored algorithm has last_update_time older than the one in database,
    # it will be deleted from cache
    def self.get_algorithm(experiment_id)
      cache_key = "workers_scaling_algorithm_#{experiment_id}"
      if @cache.exist?(cache_key)
        last_update_time = Algorithm.where({experiment_id: experiment_id},
                                           fields: [:last_update_time])
                               .first.last_update_time
        if @cache.read(cache_key).last_update_time < last_update_time
          @cache.delete(cache_key)
        end
      end

      @cache.fetch(cache_key) do
        raw_algorithm = Algorithm.where(experiment_id: experiment_id).first
        AlgorithmFactory.create_algorithm(raw_algorithm.attributes)
      end
    end

    ##
    # Starts workers scaling with default configuration for PLGrid
    def self.plgrid_default(experiment_id, user_id, worker_time_limit)
      configuration = InfrastructureFacadeFactory.get_facade_for(:qsub).get_resource_configurations(user_id).first
      if configuration.blank?
        raise InfrastructureErrors::NoCredentialsError.new('Missing credentials for PlGrid resources')
      end
      configuration.merge!({time_limit: worker_time_limit, onsite_monitoring: 'on'})
      self.initial_deployment(
              experiment_id,
              user_id,
              [{resource_configuration: configuration, limit: 5}],
              Time.now,
              {name: WorkersScaling::ResourcesUsageMaximization.get_class_name}
      )
    end

    private

    REQUIRED_ATTRIBUTES = [:class_name, :experiment_id, :user_id, :allowed_resource_configurations,
                           :planned_finish_time, :last_update_time]

    def self.validate_attributes(attributes)
      REQUIRED_ATTRIBUTES.each do |attribute|
        raise AlgorithmParameterMissing, attribute unless attributes.has_key?(attribute)
      end
    end

  end
end