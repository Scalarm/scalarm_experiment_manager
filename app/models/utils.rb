require 'json'
require 'scalarm/service_core/utils'

module Utils

  # extend this Utils with Scalarm::ServiceCore::Utils module methods
  class << self
    Scalarm::ServiceCore::Utils.singleton_methods.each do |m|
      define_method m, Scalarm::ServiceCore::Utils.method(m).to_proc
    end
  end

  def self.load_config
    # moved to secrets.yml
    # config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))

    Rails.application.secrets
  end

  def self.parse_param(params, id, parse_method)
    if params[id].blank?
      params.delete id
    else
      params[id] = parse_method.call(params[id])
    end
  end

  # Extract type of variable from given string
  #
  # * *Args*:
  #   - +value_as_string+ -> Value of parameter given as string to extract its real type
  #
  # * *Returns*:
  #   - +type_of_value+ -> Type of parameter as a string (integer, float, string or undefined)
  #
  # * *Examples*:
  #   - extract_type_from_string(value_to_check_type) -> gives single type as string
  #   - array_of_parameters.map{|value_as_string| extract_type_from_string(value_as_string)} -> gives string array of types
  #
  # * *Outputs*:
  #   - "1" -> "integer"
  #   - "-1" -> "integer"
  #   - "1.21" -> "float"
  #   - "-1.21" -> "float"
  #   - "loveRuby" -> "string"
  #   - "123.always" -> "string"
  #   - +{id: 42}+ -> "undefined"
  def self.extract_type_from_string(value_as_string)
    type_of_value = ""

    begin
      tmp_int = value_as_string.to_i
      tmp_float = value_as_string.to_f
    rescue
      return "undefined"
    end

    if value_as_string.eql? tmp_int.to_s
      type_of_value = "integer"
    elsif value_as_string.eql? tmp_float.to_s
      type_of_value = "float"
    elsif value_as_string.is_a? String
      type_of_value = "string"
    else
      type_of_value = "undefined"
    end

    type_of_value
  end

  # Extract type of variable from its value
  #
  # * *Args*:
  #   - +value+ -> Value of parameter given to extract its real type
  #
  # * *Returns*:
  #   - +type_of_value+ -> Type of parameter as a string (integer, float, string or undefined)
  #
  # * *Examples*:
  #   - extract_type_from_value(value_to_check_type) -> gives single type as string
  #   - array_of_parameters.map{|value_as_string| extract_type_from_value(value_as_string)} -> gives string array of types
  #
  # * *Outputs*:
  #   - 1 -> "integer"
  #   - -1 -> "integer"
  #   - 1.21 -> "float"
  #   - -1.21 -> "float"
  #   - "loveRuby" -> "string"
  #   - "123.always" -> "string"
  #   - +{id: 42}+ -> "undefined"
  def self.extract_type_from_value(value)
    type_of_value = ""

    if value.is_a? Integer
      type_of_value = "integer"
    elsif value.is_a? Float
      type_of_value = "float"
    elsif value.is_a? String
      type_of_value = "string"
    else
      type_of_value = "undefined"
    end

    type_of_value
  end

end