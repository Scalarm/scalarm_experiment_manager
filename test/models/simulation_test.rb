require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class SimulationTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end


  def test_input_specification
    json_record = Simulation.new({})
    json_record.expects(:get_attribute).with('input_specification').returns({"a" => 1})

    string_record = Simulation.new({})
    string_record.expects(:get_attribute).with('input_specification').returns('{"b":2}')

    soj_json = json_record.input_specification
    soj_string = string_record.input_specification

    assert_equal({"a" => 1}, soj_json)
    assert_equal({"b" => 2}, soj_string)
  end

end