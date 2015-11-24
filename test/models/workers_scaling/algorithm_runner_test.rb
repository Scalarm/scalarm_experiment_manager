require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class AlgorithmRunnerTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end

end