require 'parametrization_methods/custom_parametrization'
require 'parametrization_methods/gauss_parametrization'
require 'parametrization_methods/uniform_parametrization'
require 'parametrization_methods/range_parametrization'
require 'parametrization_methods/single_value_parametrization'
require 'parametrization_methods/design2k_parametrization'
require 'parametrization_methods/design2k1_parametrization'
require 'parametrization_methods/design2k2_parametrization'
require 'parametrization_methods/design_full_factorial_parametrization'
require 'parametrization_methods/design_latin_hypercube_parametrization'

class ParameterSpaceConverter

  def self.convert(experiment_input, doe_info = nil)
    result = {}

    experiment_input.each do |category|
      Rails.logger.debug("Parsing: #{category}")

      if category.include?('entities')
        category['entities'].each do |entity|
          Rails.logger.debug("Parsing: #{entity}")

          if entity.include?('parameters')
            entity['parameters'].each do |parameter|
              Rails.logger.debug("Parsing: #{parameter}")

              unless parameter.include?('id') and parameter.include?('type')
                throw ArgumentError.new("Either 'id' or 'type' property is missing")
              end

              label = parameter.include?('label') ? parameter['label'] : ''
              p = ApplicationParameter.new("#{category['id']}___#{entity['id']}___#{parameter['id']}".gsub(/^[_]*/,""), label, parameter['type'])

              parametrization_method = if parameter['in_doe']
                                         extract_doe_method(result, p, parameter, doe_info)
                                       else
                                         create_parametrization_method(parameter)
                                       end

              if not result.include?(parametrization_method)
                result[parametrization_method] = []
              end

              result[parametrization_method] << p
            end
          end
        end
      end
    end

    result
  end

  private

  def self.extract_doe_method(methods_and_params, param, param_element, doe_info)
    doe_method = nil

    doe_info.each do |doe_method_desc|
      if doe_method_desc[1].include?(param.id)
        doe_method = create_doe_parametrization_method(doe_method_desc)
        break
      end
    end

    if not doe_method.nil?
      if methods_and_params.include?(doe_method)
        methods_and_params[doe_method].include_param(param_element)
      end
    end

    doe_method
  end

  def self.create_parametrization_method(element)
    case element['parametrizationType']
      when 'range'
        RangeParametrization.new(cast(element['min'], element['type']), cast(element['max'], element['type']), cast(element['step'], element['type']))
      when 'value'
        SingleValueParametrization.new(cast(element['value'], element['type']))
      when 'gauss'
        GaussParametrization.new(cast(element['mean'], element['type']), cast(element['variance'], element['type']))
      when 'uniform'
        UniformParametrization.new(cast(element['min'], element['type']), cast(element['max'], element['type']))
      when 'custom'
        CustomParametrization.new(cast(parameter['custom_values'], element['type']))
    end
  end

  def self.cast(obj, type)
    if obj.kind_of?(Array)
      return obj.map{|e| cast(e, type)}
    end

    case type
      when 'integer'
        obj.to_i
      when 'float'
        obj.to_f
      when 'string'
        obj.to_s
    end
  end

  def self.create_doe_parametrization_method(doe_element)
    case doe_element.first
      when '2k'
        Design2kParametrization.new
      when 'fullFactorial'
        DesignFullFactorialParametrization.new
      when '2k-1'
        Design2k1Parametrization.new
      when '2k-2'
        Design2k2Parametrization.new
      when 'latinHypercube'
        DesignLatinHypercubeParametrization.new
    end
  end

end