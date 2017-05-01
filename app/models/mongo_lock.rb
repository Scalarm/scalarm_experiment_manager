require 'socket'

require 'scalarm/database/core'

# IMPORTANT NOTE: Locks require a unique index in MongoDB collection
# run MongoActiveRecordIndexBuilder.build_index(Scalarm::MongoLockRecord) before using it
module Scalarm

  MongoLockRecord = Database::Model::MongoLockRecord

  class MongoLock

    attr_reader :name

    def initialize(name, max_time=10.minutes)
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
      begin
        lock_dock = MongoLockRecord.collection.find_one_and_update({ name: @name }, { '$set' => { name: @name } }, upsert: true)

        if lock_dock.nil? # lock acquired
          MongoLockRecord.collection.find_one_and_update({ name: @name }, { '$set' => { pid: MongoLock.global_pid, acquired_at: Time.now } })

          Rails.logger.debug "Process #{MongoLock.global_pid} acquired lock on #{@name}"

          return true
        else
          if lock_dock['pid'] != @locked_pid
            # other process took lock in the meantime
            @locked_pid = lock_dock['pid']
            @locked_time = Time.now
          elsif timeout?
            Rails.logger.warn "LOCK TIMEOUT: Process #{MongoLock.global_pid} releases lock named \"#{@name}\" "\
              "owned by #{lock_dock['pid']}, acquired at \"#{lock_dock['acquired_at']}\" due to time limit (#{@max_time}s)"
            MongoLock.forced_release(@name)
          end

          return false
        end
      rescue Exception => e
        Rails.logger.warn "An error occured: #{e.message} - #{Process.pid} - #{MongoLockRecord.to_a}"
        return false
      end
    end

    # Releases a lock stored in Mongo database
    # @return [String] a "global_pid" of process, which originally acquired the lock,
    #   @see #global_pid for format
    def release
      old_lock = MongoLockRecord.collection.find_one_and_delete(name: @name, pid: MongoLock.global_pid)
      Rails.logger.debug "Process #{MongoLock.global_pid} released lock on #{@name}" if old_lock
      old_lock ? old_lock['pid'] : nil
    end

    def self.forced_release(name)
      MongoLockRecord.collection.delete_one({ name: name })
    end

    def self.mutex(name, probe_sec=0.1, &block)
      lock = MongoLock.new(name)

      until lock.acquire do sleep probe_sec end
      begin
        yield
      ensure
        lock.release
      end
    end

    def self.try_mutex(name, &block)
      lock = MongoLock.new(name)
      return unless lock.acquire
      begin
        yield
      ensure
        lock.release
      end
    end

  end
end
