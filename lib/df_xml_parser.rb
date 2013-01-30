require "rubygems"
require "xml"
# files dependency
require "simulation_partitioner"
require "parameter_form"

class ParameterNode
  include ParameterForm

  attr_accessor :values, :param_name, :subject, :subject_id, :min, :max,
            :default, :node_type, :subnode, :configuration_count, :label, :type

  GROUP_INDICATOR = "GGroup"
  GROUP_INDICATOR_LABEL = "Group"
  
  GLOBAL_PARAM_INDICATOR = "GlobalParameter"

  def initialize(node, rinruby)
    @rinruby = rinruby
    @values = []
    parse(node)
  end

  def values
    if @subnode then
      @subnode.values
    else
      []
    end
  end

  def parse(node)
    n = nil
    @@ns = "ns1:#{node.namespaces.default}"
    default_ns = "ns1:#{node.namespaces.default}"

    if node.find_first("ns1:Reference", default_ns) then
      @param_name = node.find_first("ns1:Reference", default_ns).content
    elsif node.find_first("ns1:Name", default_ns) then
      @param_name = node.find_first("ns1:Name", default_ns).content
    else
      @param_name = GROUP_INDICATOR + node.name
    end

    @reference = @param_name

    subject_node = node.parent.parent
    subject_node = subject_node.parent if not @param_name.starts_with?(GROUP_INDICATOR)

    @subject = subject_node.name.split("Over").first
    ns = subject_node.namespaces.default
    id_node = subject_node.find_first("ns1:#{@subject}ID", "ns1:#{ns}")
    if id_node != nil then
      @subject_id = id_node.content
      @min = node.find_first("ns1:Min", "ns1:#{ns}").content.to_f
      @max = node.find_first("ns1:Max", "ns1:#{ns}").content.to_f
      @default = node.find_first("ns1:Default", "ns1:#{ns}").content.to_f
      label_node = subject_node.find_first("ns1:#{@subject}Name", "ns1:#{ns}")
      @label = label_node.content if label_node
    end

    if node.find_first("ns1:Range", "ns1:#{node.namespaces.default}") then
      @subnode = RangeParameterNode.new(node,@rinruby)
      @node_type = "range"
    elsif node.find_first("ns1:Random", "ns1:#{node.namespaces.default}") then
      @subnode = RandomParameterNode.new(node,@rinruby)
      @node_type = "random"
    elsif node.find_first("ns1:Value", "ns1:#{node.namespaces.default}") then
      @subnode = ExplicitParameterNode.new(node,@rinruby)
      @node_type = "explicit"
    end

    #puts "Parsing: #{@param_name} --- #{@subject_id}"
  end

  def to_s
    param_id
  end

  def set_param(name, value)
    @subnode.set_param(name, value)
  end

  def configuration_count
    @subnode.configuration_count
  end

  def param_id
    [@subject, @subject_id, @param_name].join(AgentParameter::ID_DELIM)
  end

  def param_id_for_r
    # Rails.logger.debug("Param ID for R: #{param_id} --- #{ParameterForm.parameter_label(param_id).gsub(" ", "_")}");
    ParameterForm.parameter_label(param_id).gsub(" ", "_")
  end
end

class ExplicitParameterNode < ParameterNode
  attr_accessor :value

  def parse(node)
    @value = node.find_first("ns1:Value", "ns1:#{node.namespaces.default}").content.to_f
    @values = [@value]
    @type = "explicit"
    @configuration_count = 1
  end

  def set_param(name, value)
    @value = value.to_f
  end

  def values
    [@value]
  end
end

class RangeParameterNode < ParameterNode
  attr_accessor :min, :max, :step

  def parse(node)
    ns = node.namespaces.default
    @min = node.find_first("ns1:Range/ns1:Min", "ns1:#{ns}").content.to_f
    @max = node.find_first("ns1:Range/ns1:Max", "ns1:#{ns}").content.to_f
    @step = node.find_first("ns1:Range/ns1:Step", "ns1:#{ns}").content.to_f
    @partitioner = SimulationPartition.new(@min, @max, @step)
  end

  def set_param(name, value)
    self.send(name + "=", value)
    @partitioner = SimulationPartition.new(@min, @max, @step)
  end

  def values
    @partitioner.elements
  end

  def configuration_count
    @partitioner.size
  end

  def to_s
    param_id
  end
end

class RandomParameterNode < ParameterNode
  def parse(node)
    ns = node.namespaces.default
    distribution_class = node.find_first("ns1:Random/ns1:ClassName", "ns1:#{ns}").content
    distribution = distribution_class.split(".")[-1]
    @subnode = Object.const_get(distribution + "RandomParameterNode").new(node,@rinruby)
  end

  def set_param(name, value)
    @subnode.set_param(name, value)
  end

  def values
    @subnode.values
  end

  def configuration_count
    @subnode.configuration_count
  end
end

class DiscreteUniformRandomParameterNode < ParameterNode
  def parse(node)
    ns = node.namespaces.default
    node.find("ns1:Random/ns1:Parameter", "ns1:#{ns}").each do |p_node|
      node_name = p_node.find_first("ns1:Name", "ns1:#{ns}").content
      if node_name == "Min" then
        @min_node = ParameterNode.new(p_node,@rinruby)
      elsif node_name == "Max" then
        @max_node = ParameterNode.new(p_node,@rinruby)
      end
    end
  end

  def attributes
    { "min" => @min_node, "max" => @max_node }
  end

  def set_param(name, value)
    name_splitted = name.split("_")
    attributes[name_splitted[0]].set_param(name_splitted[-1], value)
  end

  def configuration_count
    @min_node.configuration_count * @max_node.configuration_count
  end

  def values
    @values = []
    @min_node.values.each do |min|
      @max_node.values.each do |max|
        @rinruby.eval("x <- runif(1, #{min}, #{max})")
        @values << ("%.3f" % (@rinruby.pull("x").to_f)).to_f
      end
    end
    @values
  end
end

class GaussianRandomParameterNode < ParameterNode
  def parse(node)
    ns = node.namespaces.default
    node.find("ns1:Random/ns1:Parameter", "ns1:#{ns}").each do |p_node|
      node_name = p_node.find_first("ns1:Name", "ns1:#{ns}").content
      if node_name == "Mean" then
        @mean_node = ParameterNode.new(p_node,@rinruby)
      elsif node_name == "Variance" then
        @variance_node = ParameterNode.new(p_node,@rinruby)
      end
    end
  end

  def attributes
    { "mean" => @mean_node, "variance" => @variance_node }
  end

  def set_param(name, value)
    name_splitted = name.split("_")
    attributes[name_splitted[0]].set_param(name_splitted[-1], value)
  end

  def configuration_count
    @mean_node.configuration_count * @variance_node.configuration_count
  end

  def values
    @values = []
    @mean_node.values.each do |min|
      @variance_node.values.each do |max|
        @rinruby.eval("x <- rnorm(1, #{min}, #{max})")
        @values << ("%.3f" % (@rinruby.pull("x").to_f)).to_f
      end
    end
    @values
  end
end

class ParameterNodeGroup
  attr_accessor :doe_method, :param_nodes, :rinruby

  def initialize(rinruby)
    @param_nodes = []
    @rinruby = rinruby
  end

  def add_param_node(node_to_add)
    @param_nodes << node_to_add
  end

  def size(design_file_path)
    case @doe_method
      when "2k" then
        2**(param_nodes.size)
      when "fullFactorial"
        @param_nodes.reduce(1){|acc, node| acc *= node.values.size}
      when *["latinHypercube", "fractionalFactorial", "nolhDesign"] then
        @rinruby.eval("arg <- #{data_frame}
          source('#{design_file_path}')
          design <- #{@doe_method}(arg)
          design <- data.matrix(design)")
        Rails.logger.info("arg <- #{data_frame}
                  source('#{design_file_path}')
                  design <- #{@doe_method}(arg)
                  design <- data.matrix(design)")
        @rinruby.design.to_a.size
    end
  end

  def values(design_file_path)
    @values = []
    data_frame = data_frame()

    if @doe_method == "2k"
      @values = @param_nodes.reduce([]) { |sum, param_node|
        sum << [param_node.subnode.min, param_node.subnode.max]
      }

    elsif @doe_method == "fullFactorial"
      @values = @param_nodes.reduce([]) { |sum, param_node|
        sum << (param_node.subnode.min..param_node.subnode.max).step(param_node.subnode.step).to_a
      }

    elsif ["latinHypercube", "fractionalFactorial", "nolhDesign"].include?(@doe_method)
      Rails.logger.info("arg <- #{data_frame}
      source('#{design_file_path}')
      design <- #{@doe_method}(arg)
      design <- data.matrix(design)")

      @rinruby.eval("arg <- #{data_frame}
      source('#{design_file_path}')
      design <- #{@doe_method}(arg)
      design <- data.matrix(design)")
      @values = @rinruby.design.to_a
    end

    @values
  end

  def data_frame
    @param_nodes.reduce("data.frame("){|data_frame, param_node|
      node_range = [param_node.subnode.min,
                    param_node.subnode.max,
                    param_node.subnode.step]
      data_frame += "#{param_node.param_id_for_r}=c(#{node_range.join(", ")}),"
    }.chop + ")"
  end

  def r_code(design_file_path)
    "arg <- #{self.data_frame}
    source('#{design_file_path}')
    design <- #{@doe_method}(arg)"
  end

  def labels
    @param_nodes.map{|param_node| param_node.param_id}
  end

  def configuration_count
    self.values.size
  end
end

def parse_df_scenario(scenario_file, rinruby)
  file = File.open(scenario_file)
  xml_string = file.read
  parser = XML::Parser.string(xml_string)
  doc, parameters = parser.parse, []

  #puts doc.to_s

  nodes = doc.find("//ns1:Parameters/ns1:Parameter", "ns1:" + doc.root.namespaces.default.to_s)
  param_nodes = nodes.map{|node| ParameterNode.new(node, rinruby)}

  nodes = doc.find("//ns1:AgentOverride/ns1:Overrides", "ns1:#{doc.root.namespaces.default}")
  nodes.each do |node|
    node.children.each do |child|
      if not child.comment? and not child.text? and child.name != "Parameters" then
        param_nodes << ParameterNode.new(child, rinruby)
      end
    end
  end

  nodes = doc.find("//ns1:AgentFlockOverride/ns1:Overrides", "ns1:#{doc.root.namespaces.default}")
  nodes.each do |node|
    node.children.each do |child|
      if not child.comment? and not child.text? and child.name != "Parameters" then
        param_nodes << ParameterNode.new(child, rinruby)
      end
    end
  end

  param_nodes.delete_if{|param_node| param_node.param_id.ends_with?("_")}

  param_nodes
end
