require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class GridCredentialsTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end


  def test_input_parameters

  end

end