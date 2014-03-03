require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class LockTest < Test::Unit::TestCase

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
  end

  def teardown
  end

  THREAD_NUM = 3
  COUNT_THREAD = 20

  PROC_NUM = 3
  COUNT_PROC = 20

  class LockTestEntry < MongoActiveRecord
    def self.collection_name
      'lock_test_entries'
    end
  end

  def test_lock_write
    data = []
    threads = []

    THREAD_NUM.times do |th_i|
      threads << Thread.new do
        lock = MongoLock.new('job')
        sleep(0.1) until lock.acquire
        COUNT_THREAD.times do
          sleep(rand*0.1)
          data << th_i
        end
        lock.release
      end
    end

    threads.each {|th| th.join }

    THREAD_NUM.times do |th_i|
      chunk = data[th_i*COUNT_THREAD..(th_i+1)*COUNT_THREAD-1]
      assert chunk.count(chunk[0]) == chunk.size, "#{th_i}: #{chunk.to_s}"
    end
  end

  def test_processes_db
    pids = []
    PROC_NUM.times do |th_i|
      pids << fork do
        lock = MongoLock.new('test_job')
        sleep(0.1) until lock.acquire
        COUNT_PROC.times do
          sleep(rand*0.1)
          LockTestEntry.new({
                                '_id'=>LockTestEntry.next_sequence,
                                'pid'=>Process.pid
                            }).save
        end
        lock.release
      end
    end

    pids.each {|pid| Process.wait pid}

    data = LockTestEntry.all

    data.sort! {|a,b| a._id <=> b._id}

    PROC_NUM.times do |th_i|
      chunk = data[th_i*COUNT_PROC..(th_i+1)*COUNT_PROC-1]
      assert ((chunk.map {|e| e.pid }).count(chunk[0].pid) == chunk.size),
             "#{th_i}: #{(chunk.map {|e| "#{e._id}. #{e.pid}"})}"
    end
  end

  def test_lock_timeout
    suspended_pid = fork do
      lock = MongoLock.new('timed_job')
      lock.acquire
      sleep(10000)
      lock.release
    end

    impatient_pid = fork do
      lock = MongoLock.new('timed_job', 3.seconds)
      sleep(0.1) until lock.acquire
      # work...
      unlocked_pid = lock.release
      assert_not_nil(unlocked_pid)
      short_pid = unlocked_pid.match(/.*?(\d+)/)[1]
      assert_equal(Process.pid, short_pid.to_i)
      Process.kill('KILL', suspended_pid)
    end

    sleep(10)
    Process.waitpid(suspended_pid, Process::WNOHANG)
    Process.waitpid(impatient_pid, Process::WNOHANG)
    assert((not LockTest.process_running? suspended_pid))
    assert((not LockTest.process_running? impatient_pid))

  end

  #def test_seq
  #  assert (1..4).map{ MongoActiveRecord.get_next_sequence('test') } == (1..4).to_a
  #  assert (1..5).map{ LockTestEntry.next_sequence } == (1..5).to_a
  #end

  def self.process_running?(pid)
    begin
      Process.getpgid pid
      true
    rescue Errno::ESRCH
      false
    end
  end

end