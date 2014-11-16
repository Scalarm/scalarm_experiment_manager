def multiple_tries(count=10, delay_sec=10, &block)
  count.times do |i|
    begin
      return yield
    rescue Exception => e
      puts "Exception occured: #{e}\n#{e.backtrace.join("\n")}"
      if i+1 < count
        puts "Try #{i+1}/#{count}, waiting #{delay_sec} seconds..."
        sleep delay_sec
      else
        raise
      end
    end
  end
end
