require 'test_helper'
require 'mocha/test_unit'

class ExperimentResourcesInterfaceTest < ActiveSupport::TestCase

  EXPERIMENT_ID = 'some_id'
  USER_ID = BSON::ObjectId.new
  SAMPLE_INFRASTRUCTURE = {name: 'name', params: {foo: 'bar'}} # TODO change to InfrastructureId class
  LIMIT = 10
  SAMPLE_LIMITS = [
      {infrastructure: SAMPLE_INFRASTRUCTURE, limit: LIMIT}
  ]
  DEFAULT_SCHEDULE_WORK_PARAMS = {
      time_limit: 60
  }

  def setup
    @sm_record_class = mock do
      stubs(:where).returns([])
    end
    @experiment = mock do
      stubs(:reload).returns(self)
      stubs(:get_statistics).returns([100, 0, 0])
      stubs(:experiment_size).returns(100)
      stubs(:id).returns(EXPERIMENT_ID)
    end
    @experiment.stubs(:sm_record_class).returns(@sm_record_class)

    Rails.stubs(:logger).returns(stub_everything)
    @resources_interface = WorkersScaling::ExperimentResourcesInterface.new(@experiment, USER_ID, SAMPLE_LIMITS)
  end

  test 'current_infrastructure_limit should return zero for infrastructure without limit' do
    # given
    resources_interface = WorkersScaling::ExperimentResourcesInterface.new(@experiment, USER_ID, {})
    # when
    assert_equal 0, resources_interface.current_infrastructure_limit(SAMPLE_INFRASTRUCTURE)
    # then
  end

  test 'current_infrastructure_limit should return limit value when workers are not running' do
    # given
    @resources_interface.expects(:get_workers_records_count).returns(0)
    # when
    assert_equal LIMIT, @resources_interface.current_infrastructure_limit(SAMPLE_INFRASTRUCTURE)
    # then
  end

  test 'current_infrastructure_limit should return proper value when some workers are running' do
    # given
    working_workers = 5
    @resources_interface.expects(:get_workers_records_count).returns(working_workers)
    # when
    assert_equal LIMIT - working_workers, @resources_interface.current_infrastructure_limit(SAMPLE_INFRASTRUCTURE)
    # then
  end

  test 'current_infrastructure_limit should return zero when to much workers are running' do
    # given
    working_workers = LIMIT + 5
    @resources_interface.expects(:get_workers_records_count).returns(working_workers)
    # when
    assert_equal 0, @resources_interface.current_infrastructure_limit(SAMPLE_INFRASTRUCTURE)
    # then
  end

  test 'schedule_workers should start workers with proper config' do
    # given
    amount = 10
    additional_params = {param1: 'value'}
    final_params = additional_params.merge(SAMPLE_INFRASTRUCTURE[:params]).merge!(DEFAULT_SCHEDULE_WORK_PARAMS)
    final_params = ActiveSupport::HashWithIndifferentAccess.new(final_params)
    start_simulation_managers_result = []
    schedule_workers_result = []
    (1..amount).each do |id|
      start_simulation_managers_result << mock do
        stubs(:sm_uuid).returns(id)
      end
      schedule_workers_result << id
    end
    facade_mock = mock
    facade_mock.stubs(:sm_record_class).returns(@sm_record_class)
    facade_mock.expects(:start_simulation_managers).with(USER_ID, amount, EXPERIMENT_ID, equals(final_params))
        .returns(start_simulation_managers_result)

    @resources_interface.expects(:get_facade_for).at_least_once.with(SAMPLE_INFRASTRUCTURE[:name]).returns(facade_mock)
    @resources_interface.stubs(:current_infrastructure_limit).returns(Float::INFINITY)

    # when
    assert_equal schedule_workers_result, @resources_interface.schedule_workers(amount,
                                                                                SAMPLE_INFRASTRUCTURE,
                                                                                additional_params)
    # then
  end

  test 'schedule workers should not start workers when limit is zero' do
    # given
    amount = 10
    @resources_interface.stubs(:current_infrastructure_limit).returns(0)
    @resources_interface.stubs(:get_workers_records_list).returns([])
    # when
    assert_equal [], @resources_interface.schedule_workers(amount, SAMPLE_INFRASTRUCTURE)
    # then
  end

  test 'schedule workers should schedule less workers when limit is lower than requested amount' do
    # given
    amount = LIMIT + 10
    facade_mock = mock
    facade_mock.stubs(:sm_record_class).returns(@sm_record_class)

    start_simulation_managers_result = []
    (1..LIMIT).each do |id|
      start_simulation_managers_result << mock do
        stubs(:sm_uuid).returns(id)
      end
    end
    facade_mock.expects(:start_simulation_managers)
        .with(anything, LIMIT, anything, anything)
        .returns(start_simulation_managers_result)

    @resources_interface.stubs(:get_facade_for).returns(facade_mock)
    @resources_interface.expects(:current_infrastructure_limit).returns(LIMIT)
    # when
    assert_equal LIMIT, @resources_interface.schedule_workers(amount, SAMPLE_INFRASTRUCTURE).count
    # then
  end

end