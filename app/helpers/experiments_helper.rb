module ExperimentsHelper

  def select_scheduling_policy
      select_tag 'scheduling_policy', options_for_select([
        ['Monte Carlo', 'monte_carlo'],
        ['Sequential forward', 'sequential_forward'],
        ['Sequential backward', 'sequential_backward']])
  end

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

end
