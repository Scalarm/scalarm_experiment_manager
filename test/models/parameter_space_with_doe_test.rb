require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ParameterSpaceWithDoeTest < MiniTest::Test

  def setup
    @p1 = ApplicationParameter.new('parameter1', '', 'integer')
    @p1_constraint = ApplicationParameterConstraint.new('parameter1', 1, 3, 1)
    @p2 = ApplicationParameter.new('parameter2', '', 'integer')
    @p2_constraint = ApplicationParameterConstraint.new('parameter2', 10, 30, 10)

  end

  def test_doe_2k_method_should_return_low_and_high_levels_for_single_parameter
    doe_method = Design2kParametrization.new([ @p1 ], [ @p1_constraint ])
    space = ParameterSpace.new([ doe_method ])

    assert_equal [ ParameterSpacePoint.new(@p1 => 1), ParameterSpacePoint.new(@p1 => 3) ], space.points
  end

  def test_doe_2k_method_should_return_combinations_of_low_and_high_levels_for_multiple_parameters
    doe_method = Design2kParametrization.new([ @p1, @p2 ], [ @p1_constraint, @p2_constraint ])
    space = ParameterSpace.new([ doe_method ])

    assert_equal [
                     ParameterSpacePoint.new(@p1 => 1, @p2 => 10),
                     ParameterSpacePoint.new(@p1 => 1, @p2 => 30),
                     ParameterSpacePoint.new(@p1 => 3, @p2 => 10),
                     ParameterSpacePoint.new(@p1 => 3, @p2 => 30)
                 ], space.points
  end


end