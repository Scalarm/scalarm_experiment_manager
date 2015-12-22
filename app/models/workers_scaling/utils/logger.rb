module WorkersScaling

  ##
  # Class responsible for formatting logs
  class TaggedLoggerFormatter

    ##
    # @param tag [Object]
    def initialize(tag)
      @tag = tag
    end

    def call(severity, time, progname, msg)
      "[#{time.strftime('%Y-%m-%d %H:%M:%S')}]#{@tag} #{'%5.5s' % severity.upcase}: #{msg.to_s.strip}\n"
    end

  end

  ##
  # Class responsible for creating loggers
  # Each logger writes to the same file
  class TaggedLoggerFactory

    ##
    # Returns logger writing to workers scaling log file
    # with adding optional tag in logged message
    # @param raw_tag [Object] must respond to .to_s
    # @return [Logger]
    def self.with_tag(raw_tag=nil)
      logger = Logger.new("#{Rails.root}/log/workers_scaling.log", 3, 1024*1024*100)
      tag = (raw_tag.nil? ? '' : "[#{raw_tag.to_s}]")
      logger.formatter = TaggedLoggerFormatter.new(tag)
      logger
    end
  end

end