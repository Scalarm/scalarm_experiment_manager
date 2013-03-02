require "parameter_form"

module ExperimentsHelper

  def json_rt_node(node, tree)
    formatted_mean = "%.2f" % node["mean"]
    node_question_text = node["question"] ? node["question"] : ""
    "{
      id: '#{node["id"]}',
      name: '#sim = #{node["n"]}, Mean MoE = #{formatted_mean}|#{node_question_text}',
      data: { 'param_id': '#{node["param_id"]}', 'param_label': '#{node["param_label"]}' },
      children: [#{
        if node.has_key?("left") then
          json_rt_node(tree[node["left"]], tree) + ", " + json_rt_node(tree[node["right"]], tree)
        else
          ""
        end
      }]
    }"
  end

  def extract_input_and_moe_names(experiment)
    done_instance = ExperimentInstance.get_first_done(experiment.id)

    if done_instance.nil?
      ['No input parameters found']
    else
      extract_moe_names(experiment) +
      %w(-----------) +
      done_instance.arguments.split(',').map{|x| [ experiment.data_farming_experiment.input_parameter_label_for(x), x]}
    end
  end

  def extract_moe_names(experiment)
    moes = experiment.moe_names

    if moes.nil?
      ["No MoEs found"]
    else
      moes.map{|x| [ParameterForm.moe_label(x), x]}
    end

  end

  def check_experiment_size_section(experiment)
    button_to_function("Check experiment size",
        "check_experiment_size(#{experiment.id})",
        :class => "nice_button") +
    image_tag("loading.gif", :id => "loading", :size => "20x20",
        :style => "display:none; float: left;")
  end

  def header_for_parameter_group(header_param)
      html =  "<h3><a href='#'>Parameters for #{header_param.type} "
      html << "with ID: #{header_param.subject_id}"
      if header_param.label then
          html << " - #{header_param.label}"
      end
      html << "</a></h3>"
  end

  def experiment_info(experiment)
      sql = "SELECT count(*) FROM experiment_instances_#{experiment.id} WHERE is_done=1"
      done = ActiveRecord::Base.connection.select_value(sql)

      "%.2f" % ((done.to_f / experiment.experiment_size) * 100)
  end

  def compute_completed(dones, size)
      # logger.debug("DD: #{dones}, #{size}")
      "%.2f" % ((dones.to_f / size.to_f) * 100)
  end

  def parametrization_select
    options_for_select({
        "Single value" => "value",
        "Range" => "range",
        "Random value - Gauss" => "gauss",
        "Random value - Uniform" => "normal" })
  end

  def render_parameter_partial(parameter)
    render :partial => "#{parameter.node_type}_parameter", :locals => {
        :editable_inputs => true,
        :parameter => parameter,
        :node => parameter.subnode,
        :parameter_id => parameter.param_id
    }
  end

  def select_doe_type
      options_for_select( [
          ["Near Orthogonal Latin Hypercubes", "nolhDesign"],
          ["2^k", "2k"],
          ["Full factorial", "fullFactorial"],
          ["Fractional factorial (with Federov algorithm)", "fractionalFactorial"],
          ["Orthogonal Latin Hypercubes", "latinHypercube"],
      ])
  end

  def select_scheduling_policy
      select_tag 'scheduling_policy', options_for_select([["Monte Carlo", "monte_carlo"],
        ["Sequential forward", "sequential_forward"],
        ["Sequential backward", "sequential_backward"]])
  end

  def parameter_label(parameter)
    label = "Parameter: \"#{parameter.parameter_label}\" - #{parameter.node_type}"

    if parameter.node_type == "random"
      label += " with #{parameter.subnode.subnode.class.name.split("Random")[0]} distribution"
    end

    label + " - Value constraints: [#{parameter.min}, #{parameter.max}]"
  end

end
