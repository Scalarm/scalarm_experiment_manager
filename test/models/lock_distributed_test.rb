require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'
require 'socket'

class LockDistributedTest < Test::Unit::TestCase

  PROC_NUM = 5
  COUNT = 50

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

  def test_processes_db

    puts 'Ready to start, press return if other remote tests are here'
    $stdin.gets.chomp

    pids = []
    PROC_NUM.times do |th_i|
      pids << fork do
        lock = MongoLock.new('test_job')
        sleep(0.1) until lock.acquire
        COUNT.times do
          sleep(rand*0.1)
          LockTestEntry.new({
                                '_id'=>LockTestEntry.next_sequence,
                                'pid'=>"#{Socket.gethostname}-#{Process.pid}"
                            }).save
        end
        lock.release
      end
    end

    pids.each {|pid| Process.wait pid}

    puts 'Entries written, press return if other remote tests are here'
    $stdin.gets.chomp

    data = LockTestEntry.all

    data.sort! {|a,b| a.id <=> b.id}

    PROC_NUM.times do |th_i|
      chunk = data[th_i*COUNT..(th_i+1)*COUNT-1]
      assert (chunk.map {|e| e.pid }).count(chunk[0].pid) == chunk.size,
             "#{th_i}: #{chunk.map{|e| e.pid }.to_s}"
    end

  end

  # Util to check what generation time is written into ObjectID
  #def test_time
  #  hostname = Socket.gethostname
  #  LockTestEntry.new({'test'=>hostname}).save
  #  entry = LockTestEntry.find_by_test hostname
  #  puts entry._id.generation_time
  #end

end