require 'socket'

class MongoLockRecord < MongoActiveRecord
  def self.collection_name
    'mongo_locks'
  end
end

class MongoLock

  def initialize(name, max_time=30.minutes)
    @locked_pid = nil
    @locked_time = nil
    @name = name
    @max_time = max_time
  end

  def self.global_pid
    "#{Socket.gethostname}-#{Process.pid}-#{Thread.current.object_id}"
  end

  def timeout?
    @locked_time ? @locked_time + @max_time < Time.now : false
  end

  def acquire
    lock_dock = MongoLockRecord.collection.find_and_modify({
  		query: { name: @name },
  		update: { '$set' => { name: @name } },
  		upsert: true
    })

    if lock_dock.nil? # lock acquired
      MongoLockRecord.collection.find_and_modify({
         query: { name: @name },
         update: { '$set' => { pid: MongoLock.global_pid } }
      })

      Rails.logger.debug "Process #{MongoLock.global_pid} acquired lock on #{@name}"
      true
    else
      if lock_dock['pid'] != @locked_pid
        # other process took lock in the meantime
        @locked_pid = lock_dock['pid']
        @locked_time = Time.now
      elsif timeout?
        Rails.logger.debug "Process #{MongoLock.global_pid} releases lock on #{@name} "\
          "owned by #{lock_dock['pid']} due to time limit"
        MongoLock.forced_release(@name)
      end

      false
    end

  end

  def release
    old_lock = MongoLockRecord.collection.find_and_modify({
       query: { name: @name, pid: MongoLock.global_pid },
       remove: true
    })
    Rails.logger.debug "Process #{MongoLock.global_pid} released lock on #{@name}" if old_lock
    old_lock ? old_lock['pid'] : nil
  end

  def self.forced_release(name)
    MongoLockRecord.collection.remove({ name: name })
  end

end