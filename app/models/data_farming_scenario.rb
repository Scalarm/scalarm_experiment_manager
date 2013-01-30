require "xml"
require "df_xml_parser"

class DataFarmingScenario

  def initialize(scenario_file_name, agent_elements = {}, parametrization_hash = {})
    @scenario_file_name = scenario_file_name
    @agent_elements = agent_elements
    @parametrization_hash = parametrization_hash
  end

  def scenario_xml
    document = LibXML::XML::Document.new

    root = XML::Node.new('DataFarmingInstance')
    root["xsi:schemaLocation"] = "http://eusas.ui.sav.sk/Eusas ../../../../schemas/DataFarmingInstance-v0.1.xsd"
    root["xmlns"] = "http://eusas.ui.sav.sk/Eusas"
    root["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"

    root << XML::Node.new('Scenario', "repository/scenarios/#{@scenario_file_name}")

    override_node = XML::Node.new('Overrides')

    @agent_elements.each do |element|
      simulation_agent = SimulationAgent.new(element, @parametrization_hash)
      override_node << simulation_agent.to_xml
    end

    root << override_node
    document.root = root

    document
  end

  def agents_layout(agent_elements)
    return nil, nil if agent_elements.blank?

    # layout is just a map['agent_group_id'] = [agent_id_1, ... ]
    layout, agent_in_hierarchy_ids = {}, []

    agent_elements.each do |agent|
      next if agent.group_id.nil?

      layout[agent.group_id] = [] if not layout[agent.group_id]
      layout[agent.group_id] << agent
      agent_in_hierarchy_ids << agent.id
    end

    return layout, agent_in_hierarchy_ids
  end

  def load_tamplate_from_cache(experiment_id)
    cache_key = "simulation_scenario_#{experiment_id}"
    if not Rails.configuration.simulation_scenarios.has_key?(cache_key)
      Rails.configuration.simulation_scenarios[cache_key] = File.read(Experiment.find(experiment_id).experiment_file_path)
    end

    @scenario_tamplate_xml = Rails.configuration.simulation_scenarios[cache_key]
  end

  def prepare_xml_for_simulation(parameters, values)
    DataFarmingScenario.prepare_simulation_xml(parameters, values, @scenario_tamplate_xml)
  end

  def self.get_and_override_parameters(experiment, params_to_override)
    parameters = parse_df_scenario(experiment.experiment_file_path, Rails.configuration.eusas_rinruby)

    parameters.each do |param_node|
      params_to_override.each do |param_to_override_name, value|

        if param_to_override_name.starts_with?(param_node.param_id) then
          subnode = param_to_override_name[(param_node.param_id.size+1)..-1]
          param_node.set_param(subnode, value.to_f)
        end
      end
    end

    parameters
  end
  
  def self.create_groups_for_doe(params_groups_for_doe, parameters)
    doe_groups = {}

    params_groups_for_doe.each do |type_and_id, param_names|
      doe_param_group = ParameterNodeGroup.new(Rails.configuration.eusas_rinruby)
      Rails.logger.debug("Type and id is #{type_and_id}")
      doe_method, group_id = type_and_id.split("_")[1..2]

      doe_param_group.doe_method = doe_method

      param_names.split(",").each do |param_name|
        node_to_add = parameters.find { |param_node| param_node.param_id == param_name }
        doe_param_group.add_param_node(node_to_add)
      end

      Rails.logger.debug("Group #{group_id} length is #{doe_param_group.param_nodes.size}")
      doe_param_group.param_nodes.each do |param_node|
        # next if not param_node
        #Rails.logger.debug("Parameter to delete #{param_node.param_id}")
        parameters.delete_if { |param_to_check| param_to_check.param_id == param_node.param_id }
      end

      doe_groups[group_id] = doe_param_group
    end

    doe_groups
  end

  # static functions
  @@EXP_RUN_PATH = "."

  def self.prepare_simulation_xml(parameters, values, xml)
    s_start, s_end = "<Scenario>", "</Scenario>"

    parameters.each_with_index do |parameter_uid, parameter_index|
      agent_type, agent_id, param_reference = AgentParameter.parse(parameter_uid)
      # Rails.logger.debug("Parameter UID: #{parameter_uid} --- Index: #{parameter_index} --- Value: #{param_value}")

      id_index = xml.index("<#{agent_type}ID>#{agent_id}</#{agent_type}ID>")
      raise "Could not find #{parameter_uid} in DF scenario xml" if id_index.nil?

      start_index, end_index, override_text = 0, 0, ""

      if param_reference.starts_with?(ParameterNode::GROUP_INDICATOR)

        parameter_name = param_reference.gsub(ParameterNode::GROUP_INDICATOR, "")

        start_index = xml.index("<#{parameter_name}>", id_index)
        end_index = xml.index("</#{parameter_name}>", start_index)+"</#{parameter_name}>".size
        override_text = global_parameter_xml(parameter_name, values[parameter_index])
      else

        start_index, end_index, override_text =
          parameter_override_info_for(param_reference, values[parameter_index], xml, id_index)
      end

      xml = xml[0..start_index-1] + override_text + xml[end_index..-1]
    end

    scenario_path = xml[(xml.index(s_start) + s_start.size)..xml.index(s_end)-1]
    scenario_path = File.join(@@EXP_RUN_PATH, scenario_path)

    xml[0..(xml.index(s_start) + s_start.size - 1)] + scenario_path + xml[xml.index(s_end)..-1]
  end

  def self.global_parameter_xml(parameter_name, parameter_value)
    parameter_text = "<#{parameter_name}>"

    if ["Size", "Heading"].include?(parameter_name)
      parameter_text += "<Value>#{parameter_value.to_i}</Value><Min>0</Min><Max>0</Max><Default>0</Default>"
    else
      parameter_text += "<Value>#{parameter_value}</Value>"
    end

    parameter_text + "</#{parameter_name}>"
  end

  def self.parameter_override_info_for(param_reference, param_value, xml, start_position)
    reference_tag = "#{param_reference}</Reference>"

    reference_index = xml.index(reference_tag, start_position)

    end_p_index = reference_index + 1
    start_p_index = reference_index

    while start_p_index and start_p_index < end_p_index do
      start_p_index = xml.index(@@param_start_tag, start_p_index)
      start_p_index += 1 if start_p_index

      end_p_index = xml.index(@@param_end_tag, end_p_index)
      end_p_index += 1 if end_p_index
    end

    start_p_index = xml.rindex(@@param_start_tag, reference_index)
    id_index_start = xml.rindex(@@ref_start_tag, reference_index)
    parameter_text = @@param_start_tag +
        xml[id_index_start..reference_index + reference_tag.size] +
        "<Value>#{param_value}</Value>" +
        "<Min>0</Min><Max>0</Max><Default>0</Default>" + @@param_end_tag

    return start_p_index, end_p_index+@@param_end_tag.size, parameter_text
  end

  @@param_start_tag, @@param_end_tag = "<Parameter>", "</Parameter>"
  @@ref_start_tag = "<Reference>"

  add_execution_time_logging :load_tamplate_from_cache, :prepare_xml_for_simulation
end
