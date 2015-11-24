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
                     .map { |klass| [klass.name.split('::')[-1].underscore.to_sym, klass] }
                     .to_h

    ##
    # Returns list of symbols representing all available Algorithm implementations
    def self.get_algorithms
      ALGORITHMS.keys
    end

    ##
    # Arguments:
    # * name - symbol representing Algorithm implementation
    # * experiment,
    #   user_id,
    #   allowed_infrastructures,
    #   planned_finish_time - standard attributes for Algorithms (see #SampleAlgorithm for example)
    # * params - hash with additional parameters for specific Algorithm implementations
    # Returns new instance of Algorithm implementation for given name
    # Raises AlgorithmNameUnknown if given name is unknown
    # Raises AlgorithmParameterMissing if attributes required by Algorithm implementation are not present in params
    def self.create_algorithm(name, experiment, user_id, allowed_infrastructures, planned_finish_time, params = {})
      raise AlgorithmNameUnknown unless ALGORITHMS.keys.include? name
      ALGORITHMS[name].new(experiment, user_id, allowed_infrastructures, planned_finish_time, params)
    end

  end
end