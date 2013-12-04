module Kernel
  def slog(component, message)
    puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} - [#{component}] #{message}"
  end
end