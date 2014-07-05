module Gsi
  class ClientError < StandardError; end
  class ProxyError < ClientError; end
  class InvalidProxyError < ProxyError; end
  class ProxyExpiredError < ProxyError; end
  class TimeoutError < ClientError; end

  def self.handle_init_error(output)
    case output
      when /Could not find a valid proxy certificate file location/
        raise InvalidProxyError
      when /The proxy credential.*expired/m
        raise ProxyExpiredError
      else
        raise ClientError.new("Unknown gsissh init error: #{output}")
    end
  end

  def self.assemble_proxy_certificate(proxy_cert, proxy_priv_key, user_cert)
    ([proxy_cert, proxy_priv_key, user_cert].map {|text| text.gsub('<br>', "\n")}).join('')
  end
end