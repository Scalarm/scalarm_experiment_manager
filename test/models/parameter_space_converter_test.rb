require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ParameterSpaceConverterTest < MiniTest::Test

  def test_space_with_doe_conversion
    sampling_methods = ParameterSpaceConverter.convert(
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
        [
            ["2k", ["main_category___main_group___parameter1"], [[1], [3]]]
        ]
    )

    assert_equal 3, sampling_methods.size

    sampling_methods.each_with_index do |sampling_method, index|
      case index
        when 0
          assert sampling_method.kind_of?(Design2kParametrization)
          assert_equal [ ApplicationParameter.new('main_category___main_group___parameter1', 'Param1', 'integer') ], sampling_method.parameters
        when 1
          assert_equal RangeParametrization.new(ApplicationParameter.new('main_category___main_group___parameter2', '', 'integer'), 1, 3, 1), sampling_method
        when 2
          assert_equal SingleValueParametrization.new(ApplicationParameter.new('main_category___main_group___parameter3', '', 'integer'), 2), sampling_method
      end
    end
  end

  def test_flat_space_conversion
    sampling_methods = ParameterSpaceConverter.convert(
        [{"entities" => [
            {"parameters" => [
                {"id" => "param-0", "label" => "New parameter 1",
                 "type" => "integer", "min" => "0", "max" => "100",
                 "with_default_value" => false, "index" => 1,
                 "parametrizationType" => "range", "step" => "20",
                 "in_doe" => false},
                {"id" => "param-1", "label" => "New parameter 2",
                 "type" => "integer", "min" => 0, "max" => 100,
                 "with_default_value" => false, "index" => 2,
                 "parametrizationType" => "value", "value" => "0",
                 "in_doe" => false}]}]}],
        []
    )

    assert_equal 2, sampling_methods.size

    sampling_methods.each_with_index do |method, index|
      case index
        when 0
          assert_equal RangeParametrization.new(ApplicationParameter.new('param-0', 'New parameter 1', 'integer'), 0, 100, 20), method
        when 1
          assert_equal SingleValueParametrization.new(ApplicationParameter.new('param-1', 'New parameter 2', 'integer'), 0), method
      end
    end
  end

  def test_space_with_multiple_parameters_conversion
    sampling_methods = ParameterSpaceConverter.convert(
        [{"entities" => [{"parameters" => [
            {"id" => "param-0", "index" => 1, "parametrizationType" => "range",
             "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
             "with_default_value" => false, "in_doe" => false},
            {"id" => "param-1", "index" => 2, "parametrizationType" => "range",
             "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
             "with_default_value" => false, "in_doe" => false},
            {"id" => "param-2", "index" => 3, "parametrizationType" => "range",
             "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
             "with_default_value" => false, "in_doe" => false},
            {"id" => "param-3", "index" => 4, "parametrizationType" => "range",
             "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
             "with_default_value" => false, "in_doe" => false},
            {"id" => "param-4", "index" => 5, "parametrizationType" => "range",
             "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
             "with_default_value" => false, "in_doe" => false}
        ]}]}]
    )

    assert_equal 5, sampling_methods.size

    sampling_methods.each_with_index do |method, index|
      assert_equal RangeParametrization.new(ApplicationParameter.new("param-#{index}", '', 'integer'), 0, 100, 20), method
    end
  end

end