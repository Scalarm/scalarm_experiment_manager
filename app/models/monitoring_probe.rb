class MonitoringProbe

  def initialize
    log('Starting')
  end
  
  def start_monitoring
    slog('monitoring_probe', "lock file exists? #{File.exists?(lock_file_path)}")
    Thread.new do

      slog('monitoring_probe', "lock file exists? #{File.exists?(lock_file_path)}")

    if File.exists?(lock_file_path)
      log('the lock file exists')
    else
      log('there is no lock file so we create one')
      IO.write(lock_file_path, Thread.current.object_id)

      at_exit{ File.delete(lock_file_path) }

      while true
        monitoring_action
        sleep(60)
      end
    end

    end
  end


  def lock_file_path
    File.join Rails.root, 'tmp', 'em_monitoring.lock'
  end


  def log(message)
    Rails.logger.debug("[monitoring-probe][#{Thread.current.object_id}] #{message}")
  end

  def monitoring_action
    log('monitoring action')

  end

end