class LoggerListener

  def execute(event)
    Rails.logger.debug("[event_handler] Registered event: #{event}")
  end

end