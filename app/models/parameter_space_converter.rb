
class ParameterSpaceConverter

  def self.convert(experiment_input, doe_info = nil)
    parametrization_methods = []

    experiment_input.each do |category|
      if category.include?('entities')
        category['entities'].each do |entity|
          if entity.include?('parameters')
            entity['parameters'].each do |raw_param_element|
              cast_parameter(raw_param_element)

              unless raw_param_element.include?('id') and raw_param_element.include?('type')
                throw ArgumentError.new("Either 'id' or 'type' property is missing")
              end

              label = raw_param_element.include?('label') ? raw_param_element['label'] : ''
              p_id  = "#{category['id']}___#{entity['id']}___#{raw_param_element['id']}".gsub(/^[_]*/,"")
              p = ApplicationParameter.new(p_id, label, raw_param_element['type'])

              if raw_param_element['in_doe']
                doe_sampling_method = extract_doe_method(p, doe_info)
                p_constraint = ApplicationParameterConstraint.new(p_id, raw_param_element['min'], raw_param_element['max'], raw_param_element['step'] )

                idx = parametrization_methods.index(doe_sampling_method)
                if idx.nil?
                  doe_sampling_method.include_parameter(p, p_constraint)
                  parametrization_methods << doe_sampling_method
                else
                  parametrization_methods[idx].include_parameter(p, p_constraint)
                end
              else
                sampling_method = create_parametrization_method(p, raw_param_element)
                parametrization_methods << sampling_method
              end
            end
          end
        end
      end
    end

    parametrization_methods
  end

  private

  def self.extract_doe_method(param, doe_info)
    doe_method = nil

    doe_info.each do |doe_method_desc|
      if doe_method_desc[1].include?(param.id)
        doe_method = create_doe_parametrization_method(doe_method_desc)
        break
      end
    end

    if doe_method.nil?
      throw new StandardError("Argument #{p} could not be find in specification of design of experiment methods")
    else
      doe_method
    end
  end

  def self.create_parametrization_method(param, element)
    case element['parametrizationType']
      when 'range'
        RangeParametrization.new(param, cast(element['min'], element['type']), cast(element['max'], element['type']), cast(element['step'], element['type']))
      when 'value'
        SingleValueParametrization.new(param, cast(element['value'], element['type']))
      when 'gauss'
        GaussParametrization.new(param, cast(element['mean'], element['type']), cast(element['variance'], element['type']))
      when 'uniform'
        UniformParametrization.new(param, cast(element['min'], element['type']), cast(element['max'], element['type']))
      when 'custom'
        CustomParametrization.new(param, cast(parameter['custom_values'], element['type']))
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

  def self.cast_parameter(parameter)
    %w(value mean variance min max step custom_values).each do |attr|
      if parameter.include?(attr)
        parameter[attr] = cast(parameter[attr], parameter['type'])
      end
    end
  end

end