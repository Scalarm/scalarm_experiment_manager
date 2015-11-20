require 'workers_scaling/utils/errors'
module WorkersScaling
  Dir["#{File.dirname(__FILE__)}/algorithms/**/*.rb"].each { |file| require file }

  ##
  # Class responsible for listing available Algorithm implementations
  # and creating instances of them
  class AlgorithmFactory

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
    # Returns list of symbols representing all available Algorithm implementations
    def self.get_algorithms
      ALGORITHMS.keys
    end

    ##
    # Arguments: attributes hash containing:
    #  * name - symbol representing Algorithm implementation
    #  * experiment_id,
    #    user_id,
    #    allowed_infrastructures,
    #    planned_finish_time,
    #    last_update_time - standard attributes for Algorithms (see #Algorithm for details)
    #  * params (optional) - hash with additional parameters for specific Algorithm implementations
    # Returns new instance of Algorithm implementation for given name
    # Raises AlgorithmNameUnknown if given name is unknown
    # Raises AlgorithmParameterMissing if attributes required by Algorithm are not present
    def self.create_algorithm(attributes)
      attributes.symbolize_keys!
      validate_attributes(attributes)
      class_name = attributes[:name].to_sym
      raise AlgorithmNameUnknown.new unless ALGORITHMS.keys.include? class_name
      ALGORITHMS[class_name].new(attributes).initialize_runtime_fields
    end


    ##
    # Returns instance of algorithm from cache
    # If Algorithm is not stored in cache, new one will be created
    # If stored algorithm has last_update_time older than the one in database,
    # it will be deleted from cache
    def self.get_algorithm(experiment_id)
      cache_key = "workers_scaling_algorithm_#{experiment_id}"
      if Rails.cache.exist?(cache_key)
        last_update_time = Algorithm.where({experiment_id: experiment_id},
                                           fields: [:last_update_time])
                               .first.last_update_time
        if Rails.cache.read(cache_key).last_update_time < last_update_time
          Rails.cache.delete(cache_key)
        end
      end

      Rails.cache.fetch(cache_key) do
        raw_algorithm = Algorithm.where(experiment_id: experiment_id).first
        AlgorithmFactory.create_algorithm(raw_algorithm.attributes)
      end
    end

    private

    REQUIRED_ATTRIBUTES = [:name, :experiment_id, :user_id, :allowed_infrastructures,
                           :planned_finish_time, :last_update_time]

    def self.validate_attributes(attributes)
      REQUIRED_ATTRIBUTES.each do |attribute|
        raise AlgorithmParameterMissing, attribute unless attributes.has_key?(attribute)
      end
    end

  end
end