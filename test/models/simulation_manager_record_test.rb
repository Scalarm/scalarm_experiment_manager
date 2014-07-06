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

  def test_experiment_end_not_running
    mock_experiment = Object
    mock_experiment.expects(:is_running).returns(false).once
    mock_experiment.expects(:experiment_size).never
    mock_experiment.expects(:get_statistics).never

    sm_record = MockRecord.new({})
    sm_record.stubs(:experiment).returns(mock_experiment)

    assert (sm_record.experiment_end?)
  end

  def test_experiment_end_all_done
    mock_experiment = Object
    mock_experiment.expects(:is_running).returns(true).once
    mock_experiment.expects(:experiment_size).returns(10).once
    mock_experiment.expects(:get_statistics).returns([10, 10, 10]).once

    sm_record = MockRecord.new({})
    sm_record.stubs(:experiment).returns(mock_experiment)

    assert (sm_record.experiment_end?)
  end

  def test_experiment_end_not
    mock_experiment = Object
    mock_experiment.expects(:is_running).returns(true).once
    mock_experiment.expects(:experiment_size).returns(10).once
    mock_experiment.expects(:get_statistics).returns([10, 10, 5]).once

    sm_record = MockRecord.new({})
    sm_record.stubs(:experiment).returns(mock_experiment)

    assert (not sm_record.experiment_end?)
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

  # TODO test_init_time_exceeded

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
    sm_record.expects(:sm_initialized).returns(false).once
    sm_record.expects(:sm_initialized_at).returns(25.minutes.ago).once
    sm_record.expects(:max_init_time).returns(20.minutes).once

    assert sm_record.init_time_exceeded?
  end

  def test_init_time_exceeded_false
    sm_record = MockRecord.new({})
    sm_record.expects(:sm_initialized).returns(false).once
    sm_record.expects(:sm_initialized_at).returns(15.minutes.ago).once
    sm_record.expects(:max_init_time).returns(20.minutes).once

    assert (not sm_record.init_time_exceeded?)
  end

  def test_init_time_exceeded_sm_init
    sm_record = MockRecord.new({})
    sm_record.expects(:sm_initialized).returns(true).once
    sm_record.expects(:initialized_at).never
    sm_record.expects(:max_init_time).never

    assert (not sm_record.init_time_exceeded?)
  end

  def test_store_error_in_db
    record = MockRecord.new({})
    MockRecord.stubs(:find_by_id).with('1').returns(record)

    record.stubs(:id).returns('1')
    record.expects(:error=).with('a').once
    record.expects(:error_log=).with('b')
    record.expects(:save).once

    record.store_error('a', 'b')
  end

  def test_store_error_not_in_db
    MockRecord.stubs(:find_by_id).with('1').returns(nil)

    record = MockRecord.new({})
    record.stubs(:id).returns('1')
    record.expects(:error=).with('a').once
    record.expects(:error_log=).with('b')
    record.expects(:save).never

    record.store_error('a', 'b')
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

end