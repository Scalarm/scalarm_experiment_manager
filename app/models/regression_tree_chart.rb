class RegressionTreeChart
  attr_reader :tree_nodes, :moe_name, :experiment

  def initialize(experiment, moe_name, rinruby)
    @experiment = experiment
    @moe_name = moe_name
    @rinruby = rinruby

    @tree_nodes = nil
  end

  def moe_label
    @moe_name
  end

  def prepare_chart_data
    result_file = Tempfile.new('regression_tree')

    result_csv = @experiment.create_result_csv_for(@moe_name)
    IO.write(result_file.path, result_csv)

    range_arguments = @experiment.range_arguments.join('+')

    @rinruby.eval("
          library(rpart)
          experiment_data <- read.csv('#{result_file.path}')
          fit <- rpart(#{@moe_name}~#{range_arguments},method='anova',data=experiment_data)
          fit_to_string <- capture.output(summary(fit))")

    begin
      @tree_nodes = parse_regression_tree_data(@rinruby.fit_to_string)
    rescue Exception => e
      Rails.logger.debug(e.inspect)
      Rails.logger.debug(e.backtrace)
      Rails.logger.info("Could not create regression tree chart for #{@moe_name}. Probably too few simulations were performed.")
    end

    result_file.unlink
  end

  def parse_regression_tree_data(tree_data)
      nodes = {}
      starting_lines = []
      tree_data.each_with_index do |line, index|
        starting_lines << index if line.start_with?('Node number')
      end

      starting_lines.each_with_index do |s_index, index|
        node_data = if index < starting_lines.size - 1 then
                      tree_data[s_index..(starting_lines[index+1] - 1)]
                    else
                      tree_data[s_index..-1]
                    end
        node_id, node_map = parse_regression_tree_node(node_data)
        nodes[node_id] = node_map
      end

      nodes
    end

  def parse_regression_tree_node(node_data)
    node_map = {}

    first_line = node_data.first
    colon_ind = first_line.index(':')
    id = first_line['Node number '.size...colon_ind].to_i
    node_map['id'] = id
    node_map['n'] = first_line[ (colon_ind + 2)..(first_line.index('observation') - 2) ].to_i

    second_line = node_data[1]
    second_line = second_line.split(',')[0]
    mean = second_line.split('=')[1].to_f
    node_map['mean'] = mean

    # check for children
    if node_data.size > 3 then
      sons_line = node_data[2]
      left_son = sons_line[(sons_line.index('=')+1)...sons_line.index('(')].to_i
      node_map['left'] = left_son

      right_son = sons_line[(sons_line.rindex('=')+1)...sons_line.rindex('(')].to_i
      node_map['right'] = right_son


      question_line = node_data[4]
      question = question_line.split('to the')[0].split(' ')
      node_map['param_id'] = question.first
      node_map['param_label'] = @experiment.input_parameter_label_for(question.first)
      question[0] = @experiment.input_parameter_label_for(question.first)
      question = question.join(' ')

      node_map['question'] = question
    end

    return id, node_map
  end

end