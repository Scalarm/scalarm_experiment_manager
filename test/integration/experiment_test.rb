require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'

class ExperimentsTest < ActionDispatch::IntegrationTest
  include DBHelper

  def create_sample_experiment
    @experiment = Experiment.new({experiment_input:
                                      [{"id" => "main_category", "label" => "Main category", "entities" =>
                                          [{"id" => "main_group", "label" => "group Main", "parameters" =>
                                              [{"id" => "parameter1", "type" => "integer", "label" => "Param1",
                                                "min" => "1", "max" => "3", "step" => "1",
                                                "with_default_value" => false, "index" => 1,
                                                "parametrizationType" => "range", "in_doe" => true},
                                               {"id" => "parameter2", "type" => "integer",
                                                "min" => "1", "max" => "3", "step" => "1",
                                                "with_default_value" => false, "index" => 2,
                                                "parametrizationType" => "range", "in_doe" => false},
                                               {"id" => "parameter3", "type" => "integer",
                                               "min" => 1, "max" => 3, "value" => "2",
                                               "with_default_value" => false, "index" => 3,
                                               "parametrizationType" => "value", "in_doe" => false}]
                                           }]
                                       }
                                      ],
                                   doe_info: [
                                    ["2k", ["main_category___main_group___parameter1"], [[1], [3]]]
                                   ]
                                 })
  end

  def setup
    super

    create_sample_experiment
  end

  def teardown
    super
  end

  test 'experiment should return response names from runs without any errors' do
    @experiment.simulation_runs.new({result: { "error_param1" => 1, "error_param2" => 2 }, is_error: true}).save
    @experiment.simulation_runs.new({result: { "param1" => 1, "param2" => 2 }}).save

    assert_equal ["param1", "param2"], @experiment.result_names
  end

end
