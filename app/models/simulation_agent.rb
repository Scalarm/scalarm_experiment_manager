require "xml"

class SimulationAgent

  def initialize(agent_element, parametrization_types)
    @agent_element = agent_element
    @parametrization_types = parametrization_types
  end

  def to_xml
    element_node = XML::Node.new("#{@agent_element.type}Override")

    element_node << XML::Node.new("#{@agent_element.type}ID", @agent_element.id)
    #element_node << XML::Node.new("#{@agent_element.type}Name", @agent_element.label)

    element_override_node = XML::Node.new("Overrides")

    parameters_node = XML::Node.new("Parameters")
    @agent_element.parameters.each do |agent_parameter|
      agent_parameter.parametrization_hash = @parametrization_types

      if agent_parameter.global_parameter?
        element_override_node << agent_parameter.to_xml
      else
        parameters_node << agent_parameter.to_xml
      end

    end

    element_override_node << parameters_node
    element_node << element_override_node

    element_node
  end

end
