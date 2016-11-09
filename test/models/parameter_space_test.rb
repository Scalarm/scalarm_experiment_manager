require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ParameterSpaceTest < MiniTest::Test

  def setup
    @simplest_sampling_methods = [SingleValueParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 1)]
    @ranges_sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-2', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-3', '', 'integer'), 0, 100, 20),
        RangeParametrization.new(ApplicationParameter.new('param-4', '', 'integer'), 0, 100, 20)
    ]
    @combined_sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 100, 20),
        SingleValueParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0)
    ]
  end

  def test_simplest_parameter_space_size
    assert_equal 1, ParameterSpace.new(@simplest_sampling_methods).size
  end

  def test_parameter_space_size_with_ranges_size
    assert_equal 6**5, ParameterSpace.new(@ranges_sampling_methods).size
  end

  def test_parameter_space_size_with_ranges_and_single_values
    assert_equal 6, ParameterSpace.new(@combined_sampling_methods).size
  end

  def test_parameter_space_size_for_compound_space
    p1 = ParameterSpace.new(@combined_sampling_methods)
    p2 = ParameterSpace.new(@ranges_sampling_methods)

    assert_equal 6**5 + 6, (p1 + p2).size
  end

  def test_parameter_space_points_generation_for_single_value
    assert_equal [ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 1)], ParameterSpace.new(@simplest_sampling_methods).points
  end

  def test_parameter_space_points_generation_for_single_value_and_range
    assert_equal [ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 60, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 80, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 100, ApplicationParameter.new('param-1', '', 'integer') => 0)], ParameterSpace.new(@combined_sampling_methods).points
  end

  def test_parameter_space_points_generation_for_range_samplings
    sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 40, 20),
        RangeParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0, 40, 20),
    ]

    assert_equal [ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 20),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 40),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 20),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 40),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 20),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 40)], ParameterSpace.new(sampling_methods).points
  end

  def test_parameter_space_points_generation_for_compound_space
    p1 = ParameterSpace.new(@combined_sampling_methods)

    sampling_methods = [
        RangeParametrization.new(ApplicationParameter.new('param-0', '', 'integer'), 0, 40, 20),
        RangeParametrization.new(ApplicationParameter.new('param-1', '', 'integer'), 0, 40, 20)
    ]

    p2 = ParameterSpace.new(sampling_methods)

    assert_equal [ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 60, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 80, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 100, ApplicationParameter.new('param-1', '', 'integer') => 0),

                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 20),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 0, ApplicationParameter.new('param-1', '', 'integer') => 40),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 20),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 20, ApplicationParameter.new('param-1', '', 'integer') => 40),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 0),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 20),
                  ParameterSpacePoint.new(ApplicationParameter.new('param-0', '', 'integer') => 40, ApplicationParameter.new('param-1', '', 'integer') => 40)], (p1 + p2).points
  end

  def test_value_list_for_simplest_samplings
      assert_equal [ [1] ], ParameterSpace.new(@simplest_sampling_methods).value_list
  end

  def test_value_list_for_range_samplings
    assert_equal [
                     [0, 20, 40, 60, 80, 100], [0, 20, 40, 60, 80, 100], [0, 20, 40, 60, 80, 100], [0, 20, 40, 60, 80, 100], [0, 20, 40, 60, 80, 100]
                 ], ParameterSpace.new(@ranges_sampling_methods).value_list
  end

  def test_value_list_for_combined_samplings
    assert_equal [ [0, 20, 40, 60, 80, 100], [0] ], ParameterSpace.new(@combined_sampling_methods).value_list
  end

  def test_multiply_list_for_simplest_samplings
      assert_equal [ 1 ], ParameterSpace.new(@simplest_sampling_methods).multiply_list
  end

  def test_multiply_list_for_range_samplings
    assert_equal [ 6*6*6*6, 6*6*6, 6*6, 6, 1], ParameterSpace.new(@ranges_sampling_methods).multiply_list
  end

  def test_multiply_list_for_combined_samplings
    assert_equal [ 1, 1 ], ParameterSpace.new(@combined_sampling_methods).multiply_list
  end

  def test_parameters_for_simplest_samplings
      assert_equal [ [ ApplicationParameter.new('param-0', '', 'integer') ] ], ParameterSpace.new(@simplest_sampling_methods).parameters
  end

  def test_parameters_for_range_samplings
    assert_equal [
                     [ ApplicationParameter.new('param-0', '', 'integer') ],
                     [ ApplicationParameter.new('param-1', '', 'integer') ],
                     [ ApplicationParameter.new('param-2', '', 'integer') ],
                     [ ApplicationParameter.new('param-3', '', 'integer') ],
                     [ ApplicationParameter.new('param-4', '', 'integer') ]
                 ], ParameterSpace.new(@ranges_sampling_methods).parameters
  end

  def test_parameters_for_combined_samplings
    assert_equal [
                     [ ApplicationParameter.new('param-0', '', 'integer') ],
                     [ ApplicationParameter.new('param-1', '', 'integer') ]
                 ], ParameterSpace.new(@combined_sampling_methods).parameters
  end

end