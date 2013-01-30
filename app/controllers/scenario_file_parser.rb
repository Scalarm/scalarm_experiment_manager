require "rubygems"
require "xml"

require "agent_element"

class ScenarioFileParser

  def self.parse_scenario_file(file_path)
    file = File.open(file_path, "r")
    xml_string = file.read
    file.close

    parser = XML::Parser.string(xml_string)
    doc, parameters = parser.parse, []
    default_ns = "ns1:#{doc.root.namespaces.default}"

    agent_instances = doc.find("//ns1:AgentInstance", default_ns)
    flock_xml_nodes = doc.find("//ns1:AgentFlock", default_ns)

    parse_agent_nodes(agent_instances, default_ns) + parse_agent_flock_nodes(flock_xml_nodes, default_ns)
  end

  def self.parse_agent_nodes(agent_instances, default_ns)
    parsed_nodes = []

    agent_instances.each do |agent_instance|

      agent = AgentElement.new
      agent.id = agent_instance.find_first("ns1:ID", default_ns).content
      agent.type = "Agent"

      group_id_node = agent_instance.find_first("ns1:groupID", default_ns)
      if group_id_node
        agent.group_id = group_id_node.content
      end

      label_node = agent_instance.find_first("ns1:Name", default_ns)
      agent.label = label_node.content if label_node
      parse_agent_parameters(agent, agent_instance, default_ns)

      parsed_nodes << agent if not agent.parameters.empty?
    end

    parsed_nodes
  end

  def self.parse_agent_flock_nodes(flock_xml_nodes, default_ns)
    parsed_nodes = []

    flock_xml_nodes.each do |flock_xml_node|

      agent = AgentElement.new
      agent.id = flock_xml_node.find_first("ns1:ID", default_ns).content
      agent.type = "AgentFlock"

      group_id_node = flock_xml_node.find_first("ns1:groupID", default_ns)
      if group_id_node
        agent.group_id = group_id_node.content
      end

      label_node = flock_xml_node.find_first("ns1:Name", default_ns)
      agent.label = label_node.content if label_node

      self.parse_flock_params(agent, flock_xml_node, default_ns)
      parse_agent_parameters(agent, flock_xml_node, default_ns)

      parsed_nodes << agent if not agent.parameters.empty?
    end

    parsed_nodes
  end

  def self.parse_agent_parameters(agent_node, agent_xml_node, default_ns)
    param_nodes = agent_xml_node.find("ns1:Parameters/ns1:Parameter", default_ns)
    param_nodes.each do |param_node|
      parse_parameter_node(agent_node, param_node, default_ns)
    end
  end

  def self.parse_parameter_node(agent_element, node, ns)
    default_features = ["Reference", "Min", "Max", "Default"]

    parameter_hash = {}
    default_features.each do |feature|
      parameter_hash[feature] = node.find_first("ns1:#{feature}", ns).content
    end

    agent_element.add_parameter(parameter_hash)
  end

  @@GLOBAL_CONSTRAINT = {
      "Heading_Min" => 0, "Heading_Max" => 360,
      "Size_Min" => 1, "Size_Max" => 50
  }

  def self.parse_flock_params(flock_node, flock_xml_node, ns)
    ["Size", "Heading"].each do |param_name|
      parameter_value = flock_xml_node.find_first("ns1:#{param_name}/ns1:Value", ns).content

      if not parameter_value.nil?
        min_value = flock_xml_node.find_first("ns1:#{param_name}/ns1:Min", ns)
        min_value = min_value.nil? ? @@GLOBAL_CONSTRAINT["#{param_name}_Min"] : min_value.content

        max_value = flock_xml_node.find_first("ns1:#{param_name}/ns1:Max", ns)
        max_value = max_value.nil? ? @@GLOBAL_CONSTRAINT["#{param_name}_Max"] : max_value.content

        default_value = flock_xml_node.find_first("ns1:#{param_name}/ns1:Default", ns)
        default_value = default_value.nil? ? parameter_value : default_value.content

        parameter_hash = {
            "Min" => min_value,
            "Max" => max_value,
            "Default" => default_value,
            "Reference" => "GlobalParameter_#{param_name}#Group_#{param_name}"
        }

        flock_node.add_parameter(parameter_hash)
      end
    end
  end

end


