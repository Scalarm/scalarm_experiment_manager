require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class SimulationRunTest < MiniTest::Test

  RESULT1 = {result: 1}
  RESULT2 = {result: 2}

  def setup
    Rails.stubs(:logger).returns(stub_everything)

    Scalarm::Database::MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    Scalarm::Database::MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}

    @simulation_run = Experiment.new({}).simulation_runs.new({})
  end

  def test_tmp_result_old_records
    @simulation_run.tmp_result = RESULT2

    assert_equal RESULT2, @simulation_run.tmp_result
  end

  def test_tmp_result_new_records
    @simulation_run.tmp_results_list = []
    @simulation_run.tmp_results_list << {'time' => Time.now, 'result' => RESULT1}
    assert_equal RESULT1, @simulation_run.tmp_result

    @simulation_run.tmp_results_list << {'time' => Time.now, 'result' => RESULT2}
    assert_equal RESULT2, @simulation_run.tmp_result
  end
end