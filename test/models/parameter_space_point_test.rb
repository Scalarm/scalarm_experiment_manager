require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ParameterSpacePointTest < MiniTest::Test

  def test_points_equality
    p1 = ParameterSpacePoint.new(x: 1, y: 1)

    assert_equal p1, ParameterSpacePoint.new(y: 1, x: 1)

    refute_equal p1, ParameterSpacePoint.new(y: 1, x: 2)
    refute_equal p1, ParameterSpacePoint.new(y: 1, x: 1, z: 1)
  end

end