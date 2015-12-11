require 'test_helper'
require 'mocha/test_unit'

class ExperimentStatisticsTest < ActiveSupport::TestCase
  def setup
    @experiment_statistics = WorkersScaling::ExperimentStatistics.new(stub_everything, stub_everything)
  end

  test 'count_simulations_to_run should always return non-negative number' do
    # given
    experiment = mock do
      stubs(:size).returns(0)
      stubs(:count_done_simulations).returns(1)
      stubs(:reload)
    end
    experiment_statistics = WorkersScaling::ExperimentStatistics.new(experiment, mock)
    # when
    simulations_to_run = experiment_statistics.send(:count_not_finished_simulations)
    # then
    assert simulations_to_run >= 0, "Number of simulations to run must be non-negative, got #{simulations_to_run}"
  end

  test 'count_simulations_to_run should always return current data' do
    # given
    experiment = mock do
      expects(:reload)
      stubs(:size).returns(0)
      stubs(:count_done_simulations).returns(0)
    end
    experiment_statistics = WorkersScaling::ExperimentStatistics.new(experiment, mock)
    # when, then
    experiment_statistics.send(:count_not_finished_simulations)
  end

  test 'count_simulations_to_run should return number of simulations to run' do
    # given
    experiment_size = 10
    done_simulations = 5
    expected_simulations_to_run = experiment_size - done_simulations
    experiment = mock do
      expects(:reload)
      stubs(:size).returns(experiment_size)
      stubs(:count_done_simulations).returns(done_simulations)
    end
    experiment_statistics = WorkersScaling::ExperimentStatistics.new(experiment, mock)
    # when
    simulations_to_run = experiment_statistics.send(:count_not_finished_simulations)
    # then
    assert_equal expected_simulations_to_run, simulations_to_run
  end

  test 'makespan should be zero when there are no simulations to run' do
    # given
    @experiment_statistics.stubs(:count_not_finished_simulations).returns(0)
    @experiment_statistics.stubs(:system_throughput).returns(0)
    # when
    makespan = @experiment_statistics.makespan
    # then
    assert_equal 0, makespan
  end

  test 'makespan should be infinity when system_throughput is zero and there are simulations to run' do
    # given
    @experiment_statistics.stubs(:count_not_finished_simulations).returns(1)
    @experiment_statistics.stubs(:system_throughput).returns(0)
    # when
    makespan = @experiment_statistics.makespan
    # then
    assert_equal Float::INFINITY, makespan
  end

  test 'makespan should return current makespan' do
    # given
    system_throughput = 1
    simulations_to_run = 1
    expected_makespan = simulations_to_run / system_throughput
    @experiment_statistics.stubs(:count_not_finished_simulations).returns(simulations_to_run)
    @experiment_statistics.stubs(:system_throughput).returns(system_throughput)
    # when
    makespan = @experiment_statistics.makespan
    # then
    assert_equal expected_makespan, makespan
  end

  test 'target_throughput should be zero when there are no simulations to run' do
    # given
    @experiment_statistics.stubs(:count_not_finished_simulations).returns(0)
    Time.stubs(:now).returns(0)
    # when
    target_throughput = @experiment_statistics.target_throughput(0)
    # then
    assert_equal 0, target_throughput
  end

  test 'target_throughput should always be non-negative number' do
    # given
    @experiment_statistics.stubs(:count_not_finished_simulations).returns(1)
    Time.stubs(:now).returns(1)
    # when
    target_throughput = @experiment_statistics.target_throughput(0)
    # then
    assert target_throughput >= 0, "target_throughput must be non-negative, got #{target_throughput}"
  end

  test 'target_throughput should return current target throughput' do
    # given
    simulations_to_run = 1
    time_now = 0
    planned_finish_time = 1
    expected_target_throughput = simulations_to_run / (planned_finish_time - time_now)
    @experiment_statistics.stubs(:count_not_finished_simulations).returns(simulations_to_run)
    Time.stubs(:now).returns(time_now)
    # when
    target_throughput = @experiment_statistics.target_throughput(planned_finish_time)
    # then
    assert_equal expected_target_throughput, target_throughput
  end

end