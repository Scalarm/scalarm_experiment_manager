require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class CustomPointsExperimentTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
    @experiment = CustomPointsExperiment.new({})
  end

  def test_single_point_hash_to_tuple
    p1, p2, p3 = (1..3).collect {|i| "param-#{i}"}
    p1v, p2v, p3v = (1..3).collect {|i| "param_#{i}_val"}
    point = {
        p3 => p3v,
        p1 => p1v,
        p2 => p2v,
    }
    @experiment.stubs(:csv_parameter_ids).returns([p1, p2, p3])

    result = @experiment.single_point_hash_to_tuple(point)

    assert_equal [p1v, p2v, p3v], result
  end

end