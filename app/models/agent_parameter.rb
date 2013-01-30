require "xml"
require "parameter_form"

class AgentParameter
  include ParameterForm

  ID_DELIM = "___"

  attr_accessor :reference, :parametrization_hash

  def initialize(parent_agent, parameter_hash, parametrization_hash = {})
    @parent_agent = parent_agent
    @parameter_hash = parameter_hash
    @parametrization_hash = parametrization_hash

  #  default parameters
    @min = @parameter_hash["Min"]
    @max = @parameter_hash["Max"]
    @default = @parameter_hash["Default"]
    @reference = @parameter_hash["Reference"]
  end

  def global_parameter?()
    self.reference.starts_with?("GlobalParameter")
  end

  def to_xml
    parameter_tag = @reference.starts_with?(ParameterNode::GLOBAL_PARAM_INDICATOR) ? @reference.split("#")[0].split("_")[1] : "Parameter"

    parameter_xml_node = XML::Node.new(parameter_tag)

    parameter_xml_node << XML::Node.new("Min", @min.to_s)
    parameter_xml_node << XML::Node.new("Max", @max.to_s)
    parameter_xml_node << XML::Node.new("Default", @default.to_s)
    # reference tag is only for proper parameters
    parameter_xml_node << XML::Node.new("Reference", @reference) if parameter_tag == "Parameter"

    # agent_parameter_uid = "#{@parent_agent.type}_#{@parent_agent.id}_#{@reference}"
    parameter_xml_node << self.send("xml_node_#{@parametrization_hash[self.parameter_uid]}")

    parameter_xml_node
  end

  def parameter_uid
    [@parent_agent.type, @parent_agent.id, @reference].join(ID_DELIM)
  end

  def self.parse(parameter_uid)
    parameter_uid.split(ID_DELIM)
  end

  private

  def xml_node_value
    XML::Node.new("Value", @default)
  end

  def xml_node_range
    range_node = XML::Node.new("Range")
    range_node << XML::Node.new("Min", @min.to_s)
    range_node << XML::Node.new("Max", @max.to_s)
    range_node << XML::Node.new("Step", ((@max.to_f - @min.to_f)/5).to_i.to_s)

    range_node
  end

  def xml_node_gauss
    random_node = XML::Node.new("Random")
    random_node << XML::Node.new("ClassName", "eusas.simulation.random.Gaussian")
    mean_node = XML::Node.new("Parameter")
    mean_node << XML::Node.new("Name", "Mean")
    element_mean = ((@max.to_f - @min.to_f) / 2).to_s
    mean_node << XML::Node.new("Value", element_mean)
    random_node << mean_node

    mean_node = XML::Node.new("Parameter")
    mean_node << XML::Node.new("Name", "Variance")
    mean_node << XML::Node.new("Value", element_mean)
    random_node << mean_node

    random_node
  end

  def xml_node_normal
    random_node = XML::Node.new("Random")
    random_node << XML::Node.new("ClassName", "eusas.simulation.random.DiscreteUniform")
    min_node = XML::Node.new("Parameter")
    min_node << XML::Node.new("Name", "Min")
    min_node << XML::Node.new("Value", @min)
    random_node << min_node

    max_node = XML::Node.new("Parameter")
    max_node << XML::Node.new("Name", "Max")
    max_node << XML::Node.new("Value", @max)
    random_node << max_node

    random_node
  end

end
