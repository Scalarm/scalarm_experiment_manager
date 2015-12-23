module WorkersScaling

  ##
  # Class responsible for formatting logs
  class LoggerFormatter

    def call(severity, time, progname, msg)
      "[#{time.strftime('%Y-%m-%d %H:%M:%S')}] #{'%5.5s' % severity.upcase}: #{msg.to_s.strip}\n"
    end

  end

  ##
  # Class creating TaggedLogging with LoggerFormatter and proper log file settings
  class TaggedLogger

    def self.create
      logger = Logger.new("#{Rails.root}/log/workers_scaling.log", 3, 1024*1024*100)
      logger.formatter = LoggerFormatter.new
      ActiveSupport::TaggedLogging.new(logger)
    end
  end

  LOGGER = TaggedLogger.create unless defined? LOGGER

end