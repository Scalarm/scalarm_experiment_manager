module ParameterForm

  def parameter_label
    ParameterForm.parameter_label(@reference)
  end

  def self.parameter_label(parameter_uid)
    splitted_reference = parameter_uid.split(AgentParameter::ID_DELIM)

    self.reference_label(splitted_reference.last)
  end

  def self.moe_label(moe_name)
    label = moe_name.split(/([[:upper:]][[:lower:]]+)/).delete_if(&:empty?).join(" ")

    label.split(" ").map{|x| x[0].capitalize + x[1..-1]}.join(" ").gsub("_", " ")
  end

  def self.parameter_label_with_agent_id(parameter_uid)
    return parameter_uid if parameter_uid.split(AgentParameter::ID_DELIM).size < 2
    
    splitted_reference = parameter_uid.split(AgentParameter::ID_DELIM)
    reference_label = self.reference_label(splitted_reference.last)

    (splitted_reference[0..1]+[reference_label]).join(" - ")
  end

  def self.reference_label(reference)
    label = if reference.split('#').size > 1
      model_name, param_name = reference.split("#")
      (model_name.start_with?("GlobalParameter") ? param_name : "#{model_name.split(".").last} #{param_name}").gsub("_", " ")
    else
      reference
    end

    label = label.gsub(ParameterNode::GROUP_INDICATOR, ParameterNode::GROUP_INDICATOR_LABEL)
    label = label.split(/([[:upper:]][[:lower:]]+)/).delete_if(&:empty?).join(" ")

    label.split(" ").map{|x| x[0].capitalize + x[1..-1]}.join(" ")
  end

  def self.parameter_uid_for_r(parameter_uid)
    parameter_label = parameter_label_with_agent_id(parameter_uid)
    # Rails.logger.debug { "Parameter uid: #{parameter_uid} --- Label: #{parameter_label}" }

    parameter_label.gsub(" - ", "_").gsub(" ", "_")
  end

  def self.parameter_label_from(r_parameter_uid)
    splitted_param_id = r_parameter_uid.split("_")

    "#{splitted_param_id[0]} - #{splitted_param_id[1]} - #{splitted_param_id[2..-1].join(" ")}"
  end

end
