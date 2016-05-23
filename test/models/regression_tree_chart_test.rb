require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class RegressionTreeChartTest < MiniTest::Test

  def setup
    @experiment = Experiment.new(
        experiment_input: [
            {"entities" => [{"parameters" => [
                {"id" => "reproduction_minimum", "label" => "Reproduction minimum", "type" => "integer", "value" => "80", "parametrizationType" => "value"},
                {"id" => "newborn_energy", "label" => "Newborn energy", "type" => "integer", "value" => "110", "parametrizationType" => "value"},
                {"id" => "transferred_energy", "label" => "Transferred energy", "type" => "integer", "value" => "50", "parametrizationType" => "value"},
                {"id" => "amount_of_iterations", "label" => "Amount of iterations (replication)", "type" => "integer", "value" => "20", "parametrizationType" => "value"},
                {"id" => "immunological_time_span", "label" => "Immunological time span", "type" => "integer", "parametrizationType" => "custom", "custom_values" => ["20", "23", "26"]},
                {"id" => "bite_transfer", "label" => "Bite transfer", "type" => "integer", "parametrizationType" => "custom", "custom_values" => ["10", "15", "20"]},
                {"id" => "mahalanobis", "label" => "Mahalanobis similarity", "type" => "float", "parametrizationType" => "custom", "custom_values" => ["1.2", "1.4"]},
                {"id" => "immunological_maturity", "label" => "Immunological maturity time", "type" => "integer", "parametrizationType" => "custom", "custom_values" => ["15", "17", "19"]},
                {"id" => "good_agent_energy", "label" => "Good agent energy", "type" => "integer", "value" => "110", "parametrizationType" => "value"},
                {"id" => "evaluation_method", "label" => "Evaluation method", "type" => "string", "parametrizationType" => "custom", "custom_values" => ["rastrigin", "schwefel"]}
            ]}]}
        ]
    )

    result_csv = IO.read(File.join(__dir__, 'sample_experiment_results.csv'))
    @experiment.stubs(:create_result_csv_for).with("fitness_calls").returns(result_csv)
  end


  def test_regression_tree_chart_data_preparation
    chart = RegressionTreeChart.new(@experiment, 'fitness_calls', RinRuby.new(false))

    success = chart.prepare_chart_data

    assert success

    expected_results = {
        1=>{"id"=>1, "n"=>108, "mean"=>80.52778, "left"=>2, "right"=>3, "param_id"=>"mahalanobis", "param_label"=>"Mahalanobis similarity", "question"=>"Mahalanobis similarity < 1.3"},
        2=>{"id"=>2, "n"=>54, "mean"=>67.55556},
        3=>{"id"=>3, "n"=>54, "mean"=>93.5, "left"=>6, "right"=>7, "param_id"=>"immunological_time_span", "param_label"=>"Immunological time span", "question"=>"Immunological time span < 24.5"},
        6=>{"id"=>6, "n"=>36, "mean"=>89.63889},
        7=>{"id"=>7, "n"=>18, "mean"=>101.2222}
    }

    expected_results.each do |node_id, node|
      assert chart.tree_nodes.include?(node_id)

      assert_equal expected_results[node_id], node
    end
  end

end