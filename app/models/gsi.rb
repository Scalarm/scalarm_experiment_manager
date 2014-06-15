module Gsi
  class ClientError < StandardError; end
  class ProxyExpiredError < ClientError; end
  class MissingProxyError < ClientError; end
  class TimeoutError < ClientError; end

  def self.handle_init_error(output)
    case output
      when /Could not find a valid proxy certificate file location/
        raise MissingProxyError
      when /The proxy credential.*expired/m
        raise ProxyExpiredError
      else
        raise ClientError.new("Unknown gsissh init error: #{output}")
    end
  end
end