class InfrastructureTaskFormatter
  def call(severity, time, progname, msg)
    "#{time.strftime('%Y-%m-%d %H:%M:%S')} #{msg.strip}\n"
  end
end

class InfrastructureTaskLogger
  @@mutex = Mutex.new
  @@infrastructures_logger = Logger.new("#{Rails.root}/log/infrastructures.log", 5, 1024*1024*100)
  @@infrastructures_logger.formatter = InfrastructureTaskFormatter.new

  def self.logger
    @@mutex.synchronize do
      @@infrastructures_logger
    end
  end

  def initialize(infrastructure_name, job_record=nil)
    if job_record
      @log_format = Proc.new do |message|
        "[#{infrastructure_name}][Exp: #{job_record.experiment_id}][SiM: #{job_record.id}][Res: #{job_record.resource_id}] - #{message}"
      end
    else
      @log_format = Proc.new do |message|
        "[#{infrastructure_name}] - #{message}"
      end
    end
  end

  def method_missing(method_name, *args, &block)
    if %w(info debug warn error).include? method_name.to_s
      InfrastructureTaskLogger.logger.send(method_name.to_s, @log_format.call(args[0], block))
    else
      super(method_name, *args, &block)
    end
  end
end
