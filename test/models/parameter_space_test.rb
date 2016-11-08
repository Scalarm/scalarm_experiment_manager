require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ParameterSpaceTest < MiniTest::Test

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @experiment_with_categories_and_doe = {
        experiment_input:
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
    }

    @experiment_with_flat_space = {experiment_input:
                                       [{"entities" => [
                                           {"parameters" => [
                                               {"id" => "param-0", "label" => "New parameter 1",
                                                "type" => "integer", "min" => "0", "max" => "100",
                                                "with_default_value" => false, "index" => 1,
                                                "parametrizationType" => "range", "step" => "20",
                                                "in_doe" => false},
                                               {"id" => "param-1", "label" => "New parameter 2 ",
                                                "type" => "integer", "min" => 0, "max" => 100,
                                                "with_default_value" => false, "index" => 2,
                                                "parametrizationType" => "value", "value" => "0",
                                                "in_doe" => false}]}]}],
                                   doe_info: []
    }

    @experiment_with_multiple_params = {experiment_input:
                                            [{"entities" => [{"parameters" => [
                                                {"id" => "param-0", "index" => 1, "parametrizationType" => "range",
                                                 "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                 "with_default_value" => false, "in_doe" => true},
                                                {"id" => "param-1", "index" => 2, "parametrizationType" => "range",
                                                 "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                 "with_default_value" => false, "in_doe" => true},
                                                {"id" => "param-2", "index" => 3, "parametrizationType" => "range",
                                                 "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                 "with_default_value" => false, "in_doe" => true},
                                                {"id" => "param-3", "index" => 3, "parametrizationType" => "range",
                                                 "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                 "with_default_value" => false, "in_doe" => true},
                                                {"id" => "param-4", "index" => 4, "parametrizationType" => "range",
                                                 "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                 "with_default_value" => false, "in_doe" => true}
                                            ]}]}]
    }
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Fake test
  def test_parameter_space_size

  end
end