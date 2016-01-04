require 'test_helper'
require 'mocha/test_unit'

class ExperimentResourcesInterfaceTest < ActiveSupport::TestCase

  EXPERIMENT_ID = 'some_id'
  USER_ID = BSON::ObjectId.new
  SAMPLE_RESOURCE_CONFIGURATION = ActiveSupport::HashWithIndifferentAccess.new({name: 'name', params: {foo: 'bar'}})
  SAMPLE_AMOUNT = 10
  LIMIT = 10
  SAMPLE_LIMITS = [
      {resource_configuration: SAMPLE_RESOURCE_CONFIGURATION, limit: LIMIT}
  ]

  def setup
    @sm_record_class = mock do
      stubs(:where).returns([])
    end
    @experiment = mock do
      stubs(:reload).returns(self)
      stubs(:count_all_generated_simulations).returns(100)
      stubs(:count_sent_simulations).returns(0)
      stubs(:count_done_simulations).returns(0)
      stubs(:experiment_size).returns(100)
      stubs(:id).returns(EXPERIMENT_ID)
    end

    Rails.stubs(:logger).returns(stub_everything)
    @resources_interface = WorkersScaling::ExperimentResourcesInterface.new(@experiment, USER_ID, SAMPLE_LIMITS)
  end

  test 'current_resource_configuration_limit should return zero for configuration without limit' do
    # given
    resources_interface = WorkersScaling::ExperimentResourcesInterface.new(@experiment, USER_ID, {})
    # when, then
    assert_equal 0, resources_interface.current_resource_configuration_limit(SAMPLE_RESOURCE_CONFIGURATION)
  end

  test 'current_resource_configuration_limit should return limit value when workers are not running' do
    # given
    @resources_interface.expects(:get_workers_records_count).returns(0)
    # when, then
    assert_equal LIMIT, @resources_interface.current_resource_configuration_limit(SAMPLE_RESOURCE_CONFIGURATION)
  end

  test 'current_resource_configuration_limit should return limit reduced by running workers when workers are running' do
    # given
    working_workers = 5
    @resources_interface.expects(:get_workers_records_count).returns(working_workers)
    # when, then
    assert_equal LIMIT - working_workers, @resources_interface.current_resource_configuration_limit(
        SAMPLE_RESOURCE_CONFIGURATION)
  end

  test 'current_resource_configuration_limit should return zero when to many workers are running' do
    # given
    working_workers = LIMIT + 5
    @resources_interface.expects(:get_workers_records_count).returns(working_workers)
    # when, then
    assert_equal 0, @resources_interface.current_resource_configuration_limit(SAMPLE_RESOURCE_CONFIGURATION)
  end

  test 'schedule_workers should start workers with given config and return theirs sm_uuids' do
    # given
    final_params = SAMPLE_RESOURCE_CONFIGURATION[:params]
    final_params = ActiveSupport::HashWithIndifferentAccess.new(final_params)
    start_simulation_managers_result = []
    schedule_workers_result = []
    (1..SAMPLE_AMOUNT).each do |id|
      start_simulation_managers_result << mock do
        stubs(:sm_uuid).returns(id)
      end
      schedule_workers_result << id
    end
    facade_mock = mock
    facade_mock.expects(:start_simulation_managers).with(USER_ID, SAMPLE_AMOUNT, EXPERIMENT_ID, equals(final_params))
        .returns(start_simulation_managers_result)

    @resources_interface.stubs(:resource_configuration_not_working?).returns(false)
    @resources_interface.stubs(:calculate_needed_workers).returns([SAMPLE_AMOUNT, []])
    @resources_interface.expects(:get_facade_for).at_least_once.with(SAMPLE_RESOURCE_CONFIGURATION[:name]).
        returns(facade_mock)

    # when, then
    assert_equal schedule_workers_result, @resources_interface.schedule_workers(SAMPLE_AMOUNT,
                                                                                SAMPLE_RESOURCE_CONFIGURATION)
  end

  test 'schedule_workers should not start workers when amount of needed workers is zero' do
    # given
    @resources_interface.stubs(:resource_configuration_not_working?).returns(false)
    @resources_interface.stubs(:calculate_needed_workers).returns([0, []])
    # when, then
    assert_equal [], @resources_interface.schedule_workers(SAMPLE_AMOUNT, SAMPLE_RESOURCE_CONFIGURATION)
  end

  ##
  # Returns list containing workers records stubs
  # @param [Fixnum] amount
  # @return [Array<#sm_uuid>]
  def get_workers_stubs(amount)
    workers_stubs = []
    (1..amount).each do |id|
      workers_stubs << mock do
        stubs(:sm_uuid).returns(id)
      end
    end
    workers_stubs
  end

  test 'schedule_workers should schedule less workers when actual neededamount is lower than requested amount' do
    # given
    amount = LIMIT + 10
    start_simulation_managers_result = get_workers_stubs(LIMIT)
    facade_mock = mock
    facade_mock.expects(:start_simulation_managers)
        .with(anything, LIMIT, anything, anything)
        .returns(start_simulation_managers_result)

    @resources_interface.stubs(:resource_configuration_not_working?).returns(false)
    @resources_interface.stubs(:get_facade_for).returns(facade_mock)
    @resources_interface.expects(:calculate_needed_workers).returns([LIMIT, []])
    # when, then
    @resources_interface.schedule_workers(amount, SAMPLE_RESOURCE_CONFIGURATION)
  end

  test 'schedule_workers should not start workers when configuration is not working' do
    # given
    @resources_interface.expects(:resource_configuration_not_working?).returns(true)
    @resources_interface.expects(:calculate_needed_workers).never
    @resources_interface.expects(:get_facade_for).never
    # when, then
    assert_equal 0, @resources_interface.schedule_workers(SAMPLE_AMOUNT, SAMPLE_RESOURCE_CONFIGURATION).count
  end

  test 'schedule_workers should raise AccessDeniedError when passed resource_configuration is not allowed' do
    # given
    resources_interface = WorkersScaling::ExperimentResourcesInterface.new(@experiment, USER_ID, [])
    resources_interface.stubs(:resource_configurations_equal?).returns(false)
    # when, then
    assert_raises AccessDeniedError do
      resources_interface.schedule_workers(SAMPLE_AMOUNT, SAMPLE_RESOURCE_CONFIGURATION)
    end
  end

  test 'schedule_workers should include already_scheduled_workers in final workers sm_uuids list' do
    # given
    amount = 10
    already_scheduled_workers_count = 5
    start_simulation_managers_result = get_workers_stubs(amount - already_scheduled_workers_count)
    already_scheduled_workers = (1..already_scheduled_workers_count).to_a
    facade_mock = mock
    facade_mock.expects(:start_simulation_managers)
        .with(anything, anything, anything, anything)
        .returns(start_simulation_managers_result)

    @resources_interface.stubs(:resource_configuration_not_working?).returns(false)
    @resources_interface.stubs(:get_facade_for).returns(facade_mock)
    @resources_interface.expects(:calculate_needed_workers)
        .returns([already_scheduled_workers_count, already_scheduled_workers])
    # when, then
    assert_equal start_simulation_managers_result.map(&:sm_uuid) + already_scheduled_workers,
                 @resources_interface.schedule_workers(amount, SAMPLE_RESOURCE_CONFIGURATION)
  end

  test 'get_available_resource_configurations should return all available resource configurations' do
    # given
    @resources_interface.stubs(:get_enabled_resource_configurations).returns(
        [ActiveSupport::HashWithIndifferentAccess.new({name: 'name', params: {}})]
    )
    @resources_interface.stubs(:get_workers_records_count)
        .returns(WorkersScaling::ExperimentResourcesInterface::MAXIMUM_NUMBER_OF_FAILED_WORKERS)
    # when, then
    assert_equal [SAMPLE_RESOURCE_CONFIGURATION], @resources_interface.get_available_resource_configurations
  end

  test 'get_available_resource_configurations should not return configurations for not working infrastructures' do
    # given
    @resources_interface.stubs(:get_enabled_resource_configurations).returns(
        [ActiveSupport::HashWithIndifferentAccess.new({name: 'name', params: {}})]
    )
    @resources_interface.stubs(:get_workers_records_count)
        .returns(WorkersScaling::ExperimentResourcesInterface::MAXIMUM_NUMBER_OF_FAILED_WORKERS + 5)
    # when, then
    assert_equal [], @resources_interface.get_available_resource_configurations
  end

  test 'get_available_resource_configurations should not return configurations for not enabled infrastructures' do
    # given
    @resources_interface.stubs(:get_enabled_resource_configurations).returns([])
    @resources_interface.stubs(:get_workers_records_count)
        .returns(WorkersScaling::ExperimentResourcesInterface::MAXIMUM_NUMBER_OF_FAILED_WORKERS)
    # when, then
    assert_equal [], @resources_interface.get_available_resource_configurations
  end

  ENABLED_RESOURCE_CONFIGURATION = ActiveSupport::HashWithIndifferentAccess.new({name: :enabled, params: {}})

  test 'get_enabled_resource_configurations should return enabled configurations in resource_configuration format' do
    # given
    enabled_infrastructure = mock do
      stubs(:enabled_for_user?).returns(true)
      stubs(:short_name).returns('enabled')
    end
    disabled_infrastructure = mock do
      stubs(:enabled_for_user?).returns(false)
    end

    InfrastructureFacadeFactory.stubs(:get_all_infrastructures)
        .returns([enabled_infrastructure, disabled_infrastructure])
    # when, then
    assert_equal [ENABLED_RESOURCE_CONFIGURATION], @resources_interface.get_enabled_resource_configurations
  end
end