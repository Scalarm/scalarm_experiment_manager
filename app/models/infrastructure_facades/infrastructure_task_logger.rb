class InfrastructureTaskLogger
  def initialize(infrastructure_name, task_id=nil)
    if task_id
      @log_format = Proc.new do |message|
        "[#{infrastructure_name}][#{task_id.to_s}] #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{message}"
      end
    else
      @log_format = Proc.new do |message|
        "[#{infrastructure_name}] #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{message}"
      end
    end
  end

  def method_missing(method_name, *args, &block)
    if %w(info debug warn error).include? method_name.to_s
      Rails.logger.send(method_name.to_s, @log_format.call(args[0], block))
    else
      super(method_name, *args, &block)
    end
  end
end
