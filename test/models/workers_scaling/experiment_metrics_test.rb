require 'test_helper'
require 'mocha/test_unit'

class ExperimentMetricsTest < ActiveSupport::TestCase
  def setup
    @experiment_metrics = WorkersScaling::ExperimentMetrics.new(stub_everything, stub_everything)
  end

  test 'count_not_finished_simulations should always return non-negative number' do
    # given
    experiment = mock do
      stubs(:size).returns(0)
      stubs(:count_done_simulations).returns(1)
      stubs(:reload)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(experiment, mock)
    # when
    simulations_to_run = experiment_metrics.send(:count_not_finished_simulations)
    # then
    assert simulations_to_run >= 0, "Number of simulations to run must be non-negative, got #{simulations_to_run}"
  end

  test 'count_not_finished_simulations should always return current data' do
    # given
    experiment = mock do
      expects(:reload)
      stubs(:size).returns(0)
      stubs(:count_done_simulations).returns(0)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(experiment, mock)
    # when, then
    experiment_metrics.send(:count_not_finished_simulations)
  end

  test 'count_not_finished_simulations should return number of simulations to run' do
    # given
    experiment_size = 10
    done_simulations = 5
    expected_simulations_to_run = experiment_size - done_simulations
    experiment = mock do
      expects(:reload)
      stubs(:size).returns(experiment_size)
      stubs(:count_done_simulations).returns(done_simulations)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(experiment, mock)
    # when
    simulations_to_run = experiment_metrics.send(:count_not_finished_simulations)
    # then
    assert_equal expected_simulations_to_run, simulations_to_run
  end

  test 'makespan should be zero when there are no simulations to run' do
    # given
    @experiment_metrics.stubs(:count_not_finished_simulations).returns(0)
    @experiment_metrics.stubs(:system_throughput).returns(0)
    # when
    makespan = @experiment_metrics.makespan
    # then
    assert_equal 0, makespan
  end

  test 'makespan should be infinity when system_throughput is zero and there are simulations to run' do
    # given
    @experiment_metrics.stubs(:count_not_finished_simulations).returns(1)
    @experiment_metrics.stubs(:system_throughput).returns(0)
    # when
    makespan = @experiment_metrics.makespan
    # then
    assert_equal Float::INFINITY, makespan
  end

  test 'makespan should return current makespan' do
    # given
    system_throughput = 1
    simulations_to_run = 1
    expected_makespan = simulations_to_run / system_throughput
    @experiment_metrics.stubs(:count_not_finished_simulations).returns(simulations_to_run)
    @experiment_metrics.stubs(:system_throughput).returns(system_throughput)
    # when
    makespan = @experiment_metrics.makespan
    # then
    assert_equal expected_makespan, makespan
  end

  test 'target_throughput should be zero when there are no simulations to run' do
    # given
    @experiment_metrics.stubs(:count_not_finished_simulations).returns(0)
    Time.stubs(:now).returns(0)
    # when
    target_throughput = @experiment_metrics.target_throughput(0)
    # then
    assert_equal 0, target_throughput
  end

  test 'target_throughput should always be non-negative number' do
    # given
    @experiment_metrics.stubs(:count_not_finished_simulations).returns(1)
    Time.stubs(:now).returns(1)
    # when
    target_throughput = @experiment_metrics.target_throughput(0)
    # then
    assert target_throughput >= 0, "target_throughput must be non-negative, got #{target_throughput}"
  end

  test 'target_throughput should return current target throughput' do
    # given
    simulations_to_run = 1
    time_now = 0
    planned_finish_time = 1
    expected_target_throughput = simulations_to_run / (planned_finish_time - time_now)
    @experiment_metrics.stubs(:count_not_finished_simulations).returns(simulations_to_run)
    Time.stubs(:now).returns(time_now)
    # when
    target_throughput = @experiment_metrics.target_throughput(planned_finish_time)
    # then
    assert_equal expected_target_throughput, target_throughput
  end

  test 'calculate_worker_throughput should return correctly calculated throughput' do
    # given
    finished_simulations = 1
    time_start = Time.new(0)
    time_end = Time.new(1000)
    worker = mock do
      expects(:created_at).returns(time_start)
      expects(:finished_simulations).returns(finished_simulations)
    end
    Time.stubs(:now).returns(time_end)
    expected_worker_throughput = (finished_simulations + 1)/(time_end - time_start)
    # when
    worker_throughput = @experiment_metrics.send(:calculate_worker_throughput, worker)
    # then
    assert_equal expected_worker_throughput, worker_throughput
  end


  test 'calculate_worker_throughput should correctly calculate throughput when workers does not have attribute finished_simulations' do
    # given
    time_start = Time.new(0)
    time_end = Time.new(1000)
    worker = mock do
      expects(:created_at).returns(time_start)
      expects(:finished_simulations).returns(nil)
    end
    Time.stubs(:now).returns(time_end)
    expected_worker_throughput = (0 + 1)/(time_end - time_start)
    # when
    worker_throughput = @experiment_metrics.send(:calculate_worker_throughput, worker)
    # then
    assert_equal expected_worker_throughput, worker_throughput
  end

  test 'system_throughput should calculate throughput correctly for multiple configurations with workers' do
    # given
    worker_throughput = 5
    configurations_list = [mock, mock]
    workers_list = [mock, mock]
    resources_interface = mock do
      expects(:get_enabled_resource_configurations).returns(configurations_list)
      expects(:get_workers_records_list).twice.returns(workers_list)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(mock, resources_interface)
    experiment_metrics.stubs(:calculate_worker_throughput).returns(worker_throughput)
    expected_system_throughput = configurations_list.size * workers_list.size * worker_throughput
    # when
    system_throughput = experiment_metrics.system_throughput
    # then
    assert_equal expected_system_throughput, system_throughput
  end

  test 'system_throughput should calculate throughput correctly when one of configurations has no workers' do
    # given
    worker_throughput = 5
    configurations_list = [mock, mock]
    workers_list = [mock, mock]
    resources_interface = mock do
      expects(:get_enabled_resource_configurations).returns(configurations_list)
      expects(:get_workers_records_list).twice.returns(workers_list, [])
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(mock, resources_interface)
    experiment_metrics.stubs(:calculate_worker_throughput).returns(worker_throughput)
    expected_system_throughput = workers_list.size * worker_throughput
    # when
    system_throughput = experiment_metrics.system_throughput
    # then
    assert_equal expected_system_throughput, system_throughput
  end

  test 'system_throughput should return zero when configuration has no workers' do
    # given
    worker_throughput = 5
    configurations_list = [mock]
    workers_list = []
    resources_interface = mock do
      expects(:get_enabled_resource_configurations).returns(configurations_list)
      expects(:get_workers_records_list).returns(workers_list)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(mock, resources_interface)
    experiment_metrics.stubs(:calculate_worker_throughput).returns(worker_throughput)
    expected_system_throughput = 0
    # when
    system_throughput = experiment_metrics.system_throughput
    # then
    assert_equal expected_system_throughput, system_throughput
  end

  test 'system_throughput should return zero when no configuration is available' do
    # given
    configurations_list = []
    resources_interface = mock do
      expects(:get_enabled_resource_configurations).returns(configurations_list)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(mock, resources_interface)
    expected_system_throughput = 0
    # when
    system_throughput = experiment_metrics.system_throughput
    # then
    assert_equal expected_system_throughput, system_throughput
  end

  test 'resource_configuration_throughput should calculate throughput correctly when configurations has workers' do
    # given
    worker_throughput = 5
    workers_list = [mock, mock]
    resources_interface = mock do
      expects(:get_workers_records_list).returns(workers_list)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(mock, resources_interface)
    experiment_metrics.stubs(:calculate_worker_throughput).returns(worker_throughput)
    expected_resource_configuration_throughput = workers_list.size * worker_throughput
    # when
    resource_configuration_throughput = experiment_metrics.resource_configuration_throughput(mock)
    # then
    assert_equal expected_resource_configuration_throughput, resource_configuration_throughput
  end

  test 'resource_configuration_throughput should return zero when configurations has no workers' do
    # given
    workers_list = []
    resources_interface = mock do
      expects(:get_workers_records_list).returns(workers_list)
    end
    experiment_metrics = WorkersScaling::ExperimentMetrics.new(mock, resources_interface)
    expected_resource_configuration_throughput = 0
    # when
    resource_configuration_throughput = experiment_metrics.resource_configuration_throughput(mock)
    # then
    assert_equal expected_resource_configuration_throughput, resource_configuration_throughput
  end
end