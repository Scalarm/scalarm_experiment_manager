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

  THREAD_NUM = 10
  COUNT = 100


  def test_lock_write
    data = []
    threads = []

    THREAD_NUM.times do |th_i|
      threads << Thread.new do
        sleep(0.1) until MongoLock.acquire('job')
        COUNT.times do
          sleep(rand*0.1)
          data << th_i
        end
        MongoLock.release('job')
      end
    end

    threads.each {|th| th.join }

    THREAD_NUM.times do |th_i|
      chunk = data[th_i*COUNT..(th_i+1)*COUNT-1]
      assert chunk.count(chunk[0]) == chunk.size, "#{th_i}: #{chunk.to_s}"
    end

  end

end