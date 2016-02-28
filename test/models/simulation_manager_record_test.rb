require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/simulation_manager'

class SimulationManagerRecordTest < MiniTest::Test

  class MockMongoActiveRecord
    def initialize(attributes)
    end

    def method_missing(name, *args, &block)
      nil
    end
  end

  class MockRecord < MockMongoActiveRecord
    include SimulationManagerRecord
  end

  def setup
    @record = MockRecord.new({})
  end

  def test_experiment
    mock_experiment = Object
    mock_experiment.stubs(:id).returns(1)

    Experiment.stubs(:find_by_id).with(1).returns(mock_experiment)

    sm_record = MockRecord.new({})
    sm_record.stubs(:experiment_id).returns(1)

    experiment_get = sm_record.experiment

    assert_equal 1, experiment_get.id
  end

  def test_time_limit_exceeded_true
    sm_record = MockRecord.new({})
    sm_record.expects(:created_at).returns(Time.now - 2.minutes).once
    sm_record.expects(:time_limit).returns(1).once

    assert sm_record.time_limit_exceeded?
  end

  def test_time_limit_exceeded_false
    sm_record = MockRecord.new({})
    sm_record.expects(:created_at).returns(Time.now - 2.minutes).once
    sm_record.expects(:time_limit).returns(3).once

    assert (not sm_record.time_limit_exceeded?)
  end

  def test_max_init_time_lower
    sm_record = MockRecord.new({})
    sm_record.expects(:time_limit).returns(60*72 - 5).once

    assert_equal 20.minutes, sm_record.max_init_time
  end

  def test_max_init_time_higher
    sm_record = MockRecord.new({})
    sm_record.expects(:time_limit).returns(60*72 + 5).once

    assert_equal 40.minutes, sm_record.max_init_time
  end

  def test_init_time_exceeded_true
    sm_record = MockRecord.new({})
    sm_record.expects(:state).returns(:initializing).once
    sm_record.expects(:sm_initialized_at).returns(25.minutes.ago).once
    sm_record.expects(:max_init_time).returns(20.minutes).once

    assert sm_record.init_time_exceeded?
  end

  def test_init_time_exceeded_false
    sm_record = MockRecord.new({})
    sm_record.expects(:state).returns(:initializing).once
    sm_record.expects(:sm_initialized_at).returns(15.minutes.ago).once
    sm_record.expects(:max_init_time).returns(20.minutes).once

    assert (not sm_record.init_time_exceeded?)
  end

  def test_init_time_exceeded_sm_init
    sm_record = MockRecord.new({})
    sm_record.expects(:state).returns(:running).once
    sm_record.expects(:initialized_at).never
    sm_record.expects(:max_init_time).never

    assert (not sm_record.init_time_exceeded?)
  end

  def test_old_initialized_state
    record = MockRecord.new({})
    record.stubs(:sm_initialized).returns(true)
    assert_equal :running, record.state
  end

  def test_terminating_state
    record = MockRecord.new({})
    record.stubs(:is_terminating).returns(true)
    record.stubs(:sm_initialized).returns(true)
    assert_equal :terminating, record.state
  end

  def test_use_old_state_data
    @record.stubs(:sm_initialized).returns(true)

    assert_equal :running, @record.state
  end

  def test_get_current_simulation_run_no_experiment
    @record.stubs(:experiment).returns(nil)
    @record.stubs(:sm_uuid).returns('aaa')

    @record.get_current_simulation_run
  end

  def test_cmd_delegation_time_exceeded_true
    @record.stubs(:cmd_delegated_at).returns(Time.now - 10.minutes)

    assert @record.cmd_delegation_time_exceeded?
  end

  def test_cmd_to_execute
    cmd1 = 'cmd1'
    cmd2 = 'cmd2'
    attributes_mock = {}
    @record.stubs(:attributes).returns(attributes_mock)

    @record.cmd_to_execute = cmd1
    assert_equal 'cmd1', attributes_mock['cmd_to_execute']

    @record.cmd_to_execute = cmd2
    assert_equal 'cmd1#_#cmd2', attributes_mock['cmd_to_execute']
  end

  def test_cmd_to_execute_code
    code1 = 'code1'
    code2 = 'code2'
    attributes_mock = {}
    @record.stubs(:attributes).returns(attributes_mock)

    @record.cmd_to_execute_code = code1
    assert_equal 'code1', attributes_mock['cmd_to_execute_code']

    @record.cmd_to_execute_code = code2
    assert_equal 'code1#_#code2', "#{attributes_mock['cmd_to_execute_code']}"
  end

  def test_has_more_simulations_to_run_field_greater_than_zero
    sm_record = MockRecord.new({})
    sm_record.stubs(:simulations_left).returns(1)

    assert sm_record.has_more_simulations_to_run?, 'Simulation Manager has more simulations to run when simulations_left is greater than 0'
  end

  def test_has_more_simulations_to_run_field_equal_to_zero
    sm_record = MockRecord.new({})
    sm_record.stubs(:simulations_left).returns(0)

    assert (not sm_record.has_more_simulations_to_run?), 'Simulation Manager has no more simulations to run when simulations_left is 0'
  end

  def test_has_more_simulations_to_run_field_lesser_than_zero
    sm_record = MockRecord.new({})
    sm_record.stubs(:simulations_left).returns(-1)

    assert (not sm_record.has_more_simulations_to_run?), 'Simulation Manager has no more simulations to run when simulations_left is lesser than 0'
  end

  def test_has_more_simulations_to_run_field_not_existing
    sm_record = MockRecord.new({})
    sm_record.stubs(:simulations_left).returns(nil)

    assert sm_record.has_more_simulations_to_run?, 'Simulation Manager has more simulations to run when simulations_left is not present'
  end

end