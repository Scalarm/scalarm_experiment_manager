require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class AlgorithmRunnerTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end

  def test_proper_runner_cycle
    experiment = mock do
      stubs(:reload).returns(self)
      expects(:completed?).twice.returns(false, true)
    end
    Experiment.stubs(:where).returns(experiment)

    algorithm = mock do
      expects(:initial_deployment)
      expects(:experiment_status_check).twice
    end

    runner = WorkersScaling::AlgorithmRunner.new 'id', algorithm, 0

    runner.start
    # sleep to allow new thread in runner.start finish its job
    sleep(1)
  end
end