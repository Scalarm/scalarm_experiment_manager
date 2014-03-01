require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class MyTest < Test::Unit::TestCase

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
  end

  def teardown
  end

  class LockTestEntry < MongoActiveRecord
    def self.collection_name
      'lock_test_entry'
    end
  end

  PROC_NUM = 10
  COUNT = 20

  def test_processes_db
    pids = []
    PROC_NUM.times do |th_i|
      pids << fork do
        sleep(0.1) until MongoLock.acquire('test_job')
        COUNT.times do
          sleep(rand*0.1)
          LockTestEntry.new({'pid'=>Process.pid, 'time'=>Time.now}).save
        end
        MongoLock.release('test_job')
      end
    end

    pids.each {|pid| Process.wait pid}

    data = LockTestEntry.all

    data.sort! {|a,b| a.time <=> b.time}

    PROC_NUM.times do |th_i|
      chunk = data[th_i*COUNT..(th_i+1)*COUNT-1]
      assert (chunk.map {|e| e.pid }).count(chunk[0].pid) == chunk.size, "#{th_i}: #{chunk.to_s}"
    end

  end

end