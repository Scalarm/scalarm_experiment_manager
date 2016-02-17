require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class ClusterOnsiteWorkerDelegateTest < MiniTest::Test

  def setup
    @slurm = SlurmScheduler.new
    @delegate = ClusterOnsiteWorkerDelegate.new(@slurm)
  end

  def teardown
  end

  def test_stop_cmd
    sm_record = JobRecord.new({cmd_to_execute_code: ""})
    sm_record.stubs(:save)
    expected_cmd = BashCommand.new.append(@slurm.cancel_sm_cmd(sm_record)).append(@slurm.clean_after_sm_cmd(sm_record)).to_s

    @delegate.stop(sm_record)

    assert_equal "stop", sm_record.cmd_to_execute_code
    assert_equal expected_cmd, sm_record.cmd_to_execute
  end

  def test_get_log_cmd
    sm_record = JobRecord.new({cmd_to_execute_code: ""})
    sm_record.stubs(:save)
    expected_cmd = @slurm.get_log_cmd(sm_record).to_s

    @delegate.get_log(sm_record)

    assert_equal "get_log", sm_record.cmd_to_execute_code
    assert_equal expected_cmd, sm_record.cmd_to_execute
  end

end
