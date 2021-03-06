module ExperimentsHelper

  def select_scheduling_policy
      select_tag 'scheduling_policy', options_for_select([
        ['Monte Carlo', 'monte_carlo'],
        ['Sequential forward', 'sequential_forward'],
        ['Sequential backward', 'sequential_backward']])
  end

  def json_rt_node(node, tree)
    formatted_mean = "%g" % node["mean"]
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

  def share_with_users
    ScalarmUser.all.select{|u|
      u.id != current_user.id and (@experiment.shared_with.blank? or (not @experiment.shared_with.include?(u.id)))
    }.map{ |u|
      u.login.nil? ? u.email : u.login
    }
  end

  def experiment_info_button(text_prefix, reveal_id, icon, disabled)
    link_to '#', title: t("#{text_prefix}.tooltip"), 'data-reveal-id' => reveal_id, disabled: disabled,
                 class: 'button tiny radius' do

      raw content_tag(:i, '', class: icon) + raw('&nbsp;') + t("#{text_prefix}.link")
    end

  end

  def constraints_conditions
    [">", ">="]
  end

  def supervisor_options(supervisors)
    options = []
    supervisors.each do |supervisor|
      if supervisor.has_key? 'name'
        options.append [supervisor['name'], supervisor['id']]
      else
        options.append [supervisor['id'], supervisor['id']]
      end
    end
    options_for_select options, selected: options.first
  end

  ##
  # Returns workers scaling algorithm list parsed to select options.
  def workers_scaling_options
    options = WorkersScaling::AlgorithmFactory.get_algorithms_list.map { |entry| [entry[:name], entry[:id]] }
    options_for_select options, selected: options.first
  end

  ##
  # Returns workers scaling algorithms descriptions as hash [id -> description]
  def workers_scaling_algorithms_description
    WorkersScaling::AlgorithmFactory.get_algorithms_list.map {|entry| [entry[:id], entry[:description]] }.to_h
  end

  def analysis_methods
    [ 'histogram', 'scatter_plot', 'regression_tree' ]
  end

  def analysis_methods_description
    {
        "histogram" => "Histogram shows results frequency distribution",
        "scatter_plot" => "Analysis of two variables relationship with scatter plot",
        "regression_tree" => "Classification of objects by dividing the found set of conditions"
    }
  end

  def data_explorer_base_url(url)
    return url if url.blank?

    if Rails.application.secrets.information_service_development
      "http://#{url}"
    else
      "https://#{url}"
    end
  end

end
