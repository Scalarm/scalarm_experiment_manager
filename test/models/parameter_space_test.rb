require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ParameterSpaceTest < MiniTest::Test

  def test_simplest_parameter_space_size
    sampling_methods = [SingleValueParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 1)]

    assert_equal 1, ParameterSpace.new(sampling_methods).size
  end

  def test_parameter_space_size_with_ranges_size
    sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-2', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-3', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-4', '', 'integer'), 0, 100, 20)
    ]

    assert_equal 6**5, ParameterSpace.new(sampling_methods).size
  end

  def test_parameter_space_size_with_ranges_and_single_values
    sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 100, 20),
        SingleValueParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0)
    ]

    assert_equal 6, ParameterSpace.new(sampling_methods).size
  end

  def test_parameter_space_size_for_compound_space
    sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 100, 20),
        SingleValueParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0)
    ]

    p1 = ParameterSpace.new(sampling_methods)

    sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-2', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-3', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-4', '', 'integer'), 0, 100, 20)
    ]

    p2 = ParameterSpace.new(sampling_methods)

    assert_equal 6**5 + 6, (p1 + p2).size
  end
end