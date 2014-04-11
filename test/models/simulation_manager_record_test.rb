require 'test/unit'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/simulation_manager'

class SimulationManagerRecordTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  class MockRecord
    include SimulationManagerRecord
  end

  def test_experiment
    mock_experiment = Object
    mock_experiment.stubs(:id).returns(1)

    Experiment.stubs(:find_by_id).with(1).returns(mock_experiment)

    sm_record = MockRecord.new
    sm_record.stubs(:experiment_id).returns(1)

    experiment_get = sm_record.experiment

    assert_equal 1, experiment_get.id
  end

  def test_experiment_end_not_running
    mock_experiment = Object
    mock_experiment.expects(:is_running).returns(false).once
    mock_experiment.expects(:experiment_size).never
    mock_experiment.expects(:get_statistics).never

    sm_record = MockRecord.new
    sm_record.stubs(:experiment).returns(mock_experiment)

    assert (sm_record.experiment_end?)
  end

  def test_experiment_end_all_done
    mock_experiment = Object
    mock_experiment.expects(:is_running).returns(true).once
    mock_experiment.expects(:experiment_size).returns(10).once
    mock_experiment.expects(:get_statistics).returns([10, 10, 10]).once

    sm_record = MockRecord.new
    sm_record.stubs(:experiment).returns(mock_experiment)

    assert (sm_record.experiment_end?)
  end

  def test_experiment_end_not
    mock_experiment = Object
    mock_experiment.expects(:is_running).returns(true).once
    mock_experiment.expects(:experiment_size).returns(10).once
    mock_experiment.expects(:get_statistics).returns([10, 10, 5]).once

    sm_record = MockRecord.new
    sm_record.stubs(:experiment).returns(mock_experiment)

    assert (not sm_record.experiment_end?)
  end

  def test_time_limit_exceeded_true
    sm_record = MockRecord.new
    sm_record.expects(:created_at).returns(Time.now - 2.minutes).once
    sm_record.expects(:time_limit).returns(1).once

    assert sm_record.time_limit_exceeded?
  end

  def test_time_limit_exceeded_false
    sm_record = MockRecord.new
    sm_record.expects(:created_at).returns(Time.now - 2.minutes).once
    sm_record.expects(:time_limit).returns(3).once

    assert (not sm_record.time_limit_exceeded?)
  end

  # TODO test_init_time_exceeded

end