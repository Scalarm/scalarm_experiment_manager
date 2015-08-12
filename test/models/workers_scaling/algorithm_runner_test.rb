require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class AlgorithmRunnerTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end

  def test_proper_runner_cycle
    experiment = mock do
      stubs(:id).returns('id')
      stubs(:reload).returns(self)
      expects(:completed?).twice.returns(false, true)
    end

    algorithm = mock do
      expects(:initial_deployment)
      expects(:experiment_status_check).twice
    end

    runner = WorkersScaling::AlgorithmRunner.new experiment, algorithm, 0

    runner.start.join
  end
end