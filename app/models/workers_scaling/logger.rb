module WorkersScaling
  class LogFormatter
    def call(severity, time, progname, msg)
      "[#{time.strftime('%Y-%m-%d %H:%M:%S')}] #{'%5.5s' % severity.upcase}: #{msg.strip}\n"
    end
  end

  LOGGER = Logger.new("#{Rails.root}/log/workers_scaling.log", 5, 1024*1024*100) unless defined? LOGGER
  LOGGER.formatter = LogFormatter.new

end