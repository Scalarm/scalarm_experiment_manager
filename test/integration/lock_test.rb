require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'
require 'mongo_lock'

require 'scalarm/database/core'

# NOTICE: long execution time (ca. 23 seconds)
class LockTest < MiniTest::Test
  include DBHelper

  def setup
    super
  end

  def teardown
    super
  end

  THREAD_NUM = 3
  COUNT_THREAD = 20

  PROC_NUM = 3
  COUNT_PROC = 20

  class LockTestEntry < Scalarm::Database::MongoActiveRecord
    def self.collection_name
      'lock_test_entries'
    end
  end

  def test_lock_write
    data = []
    threads = []

    THREAD_NUM.times do |th_i|
      threads << Thread.new do
        lock = Scalarm::MongoLock.new('job')
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
        lock = Scalarm::MongoLock.new('test_job')
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
      lock = Scalarm::MongoLock.new('timed_job')
      lock.acquire
      sleep(10000)
      lock.release
    end

    impatient_pid = fork do
      lock = Scalarm::MongoLock.new('timed_job', 3.seconds)
      sleep(0.1) until lock.acquire
      # work...
      unlocked_pid = lock.release
      refute_nil(unlocked_pid)
      short_pid = unlocked_pid.match(/.*?(\d+)/)[1]
      assert_equal(Process.pid, short_pid.to_i)
      Process.kill('KILL', suspended_pid)
    end

    sleep(10)
    Process.waitpid(suspended_pid, Process::WNOHANG)
    Process.waitpid(impatient_pid, Process::WNOHANG)
    refute LockTest.process_running?(suspended_pid)
    refute LockTest.process_running?(impatient_pid)

  end

  def test_lock_two_threads
    count = 3
    queue = Queue.new

    writer = Thread.new do
      w_lock = Scalarm::MongoLock.new 'writer'
      assert(w_lock.acquire)
      count.times do
        queue << 1
        sleep 1
      end
      w_lock.release
    end

    reader = Thread.new do
      require 'timeout'
      r_lock = Scalarm::MongoLock.new 'reader'
      assert(r_lock.acquire)
      begin
        results = []
        Timeout::timeout count*2 do
          count.times do
            results << queue.pop
          end
        end
        assert_equal results.size, count
        assert_equal (results.inject :+), count
      rescue Timeout::Error
        assert false, 'timeout waiting for reader'
      end
      r_lock.release
    end

    [writer, reader].each {|t| t.join}

  end

  def test_mutex_two_threads
    require 'timeout'
    timeout 20 do

      count = 3
      queue = Queue.new

      writer = Thread.new do
        Scalarm::MongoLock.mutex 'writer' do
          count.times do
            queue << 1
            sleep 1
          end
        end
      end

      reader = Thread.new do
        require 'timeout'
        Scalarm::MongoLock.mutex 'reader' do
          begin
            results = []
            Timeout::timeout count*2 do
              count.times do
                results << queue.pop
              end
            end
            assert_equal results.size, count
            assert_equal (results.inject :+), count
          rescue Timeout::Error
            assert false, 'timeout waiting for reader'
          end
        end
      end

      [writer, reader].each {|t| t.join}
    end
  end

  def test_first_acquire_of_lock_should_set_a_lock_date
    lock_name = 'test_1234'

    lock = Scalarm::MongoLock.new(lock_name)
    lock.acquire

    second_pid = fork do
      lock = Scalarm::MongoLock.new(lock_name, 20.seconds)
      sleep(3)
      lock.acquire
    end

    sleep(5)

    lock_record = Scalarm::MongoLockRecord.where(name: lock_name).first

    begin
      refute_nil lock_record.acquired_at, 'lock record should have acquired_at field after acquire'

      assert (lock_record.acquired_at <= (Time.now - 5.seconds)),
             "lock should have acquired_at set at least 5 seconds ago (#{(Time.now - 5.seconds)}), but is: #{lock_record.acquired_at}"
    ensure
      Process.kill('KILL', second_pid)
    end
  end

  def self.process_running?(pid)
    begin
      Process.getpgid pid
      true
    rescue Errno::ESRCH
      false
    end
  end

end