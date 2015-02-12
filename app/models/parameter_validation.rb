module ParameterValidation

  class ValidationError < StandardError
    attr_accessor :param_name, :value, :message

    def initialize(param_name, value, message)
      @param_name = param_name
      @value = value
      @e_message = message
    end

    def to_s
      "Validation error for parameter #{@param_name}: #{@value} - #{@e_message}"
    end

    def message
      self.to_s
    end
  end

  class MissingParametersError < StandardError
    attr_accessor :parameters

    def initialize(parameters)
      @parameters = parameters
    end

    def to_s
      "Missing parameters: #{@parameters.join(', ')}"
    end

    def message
      self.to_s
    end
  end

  # Invoke all validator functions with: fun(param_name, value)
  # Functions can be both Proc or Symbol (invoked with send)
  # Special function symbols:
  # - :optional - parameter is not mandatory (by default all parameters are mandatory)
  def single_param_validation(param_name, value, functions)
    functions = [functions] unless functions.kind_of? Array
    functions.collect do |f|
      case f
        when Proc
          f.(param_name, value)
        when Symbol
          send(f, param_name, value) unless f == :optional # [:optional].include? f
        else
          Rails.logger.error("Not supported validator type: #{f} -> #{f.class}")
      end
    end
  end

  # params - all parameters Hash (eg. from controller)
  # validators - Hash: param_name => Array with validation functions
  # Validation function should be Proc or method Symbol; it must take: fun(param_name, param_value)
  # and should throw exception if there is validation error (preferable ValidationError).
  def validate_params(params, validators)
    required_params = (validators.select do |_, v|
      not (v.kind_of?(Array) ? v.include?(:optional) : v == :optional)
    end).keys
    missing_params = required_params - params.keys.collect(&:to_sym)
    raise MissingParametersError.new(missing_params) unless missing_params.empty?
    validators.each do |key, functions|
      single_param_validation(key, params[key], functions) if params.include?(key)
    end
  end

  def method_missing(method_name, *args, &block)
    security_match = method_name.to_s.match(/security_(.*)/)
    if security_match
      validate_security(security_match[1].to_sym, *args)
    else
      super
    end
  end

  def validate_security(mode, param_name, value)
    regexp = Utils::get_validation_regexp(mode)

    if regexp.match(value).nil?
      raise SecurityError.new(t('errors.insecure_parameter', param_name: param_name))
    end
  end

  def positive(name, value)
    num_value = Float value rescue raise ValidationError.new(name, value, 'Not a number')
    raise ValidationError.new(name, value, 'Not a positive number') unless num_value > 0
  end

  def integer(name, value)
    Integer value rescue raise ValidationError.new(name, value, 'Not an integer')
  end

  def float(name, value)
    Float value rescue raise ValidationError.new(name, value, 'Not a float')
  end

  def string(name, value)
    raise ValidationError.new(name, value, 'Not a string') unless value.kind_of? String
  end

end