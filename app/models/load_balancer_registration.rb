require 'net/http'
require 'socket'
require 'ipaddr'
require 'openssl'

class LoadBalancerRegistration

  def self.get_load_balancer_address
    unless Rails.application.secrets.include? :multicast_address
      raise StandardError.new("multicast_address is missing in secrets configuration")
    end
    multicast_addr, port  = Rails.application.secrets[:multicast_address].split(':')
    bind_addr = '0.0.0.0'
    message = 'error'
    begin
      socket = UDPSocket.new
      membership = IPAddr.new(multicast_addr).hton + IPAddr.new(bind_addr).hton

      socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
      socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

      socket.bind(bind_addr, port)
      begin
        timeout(30) do
          message, _ = socket.recvfrom(20)
        end
      rescue Timeout::Error => e
        puts "Unable to receive load balancer address: #{e.message}"
      end
    rescue SocketError => e
      puts "Unable to establish multicast connection: #{e.message}"
    end
    message.strip
  end

  def self.load_balancer_query(query_type)
    raise ArgumentError.new('Incorrect query to load balancer') unless ['register', 'unregister'].include?(query_type)
    message = self.get_load_balancer_address
    if message != 'error'
      port = (Rails.application.secrets[:port] or '3000')
      scheme = 'https'
      if Rails.application.secrets.load_balancer_development
        scheme = 'http'
      end
      load_balancer_address = "#{scheme}://#{message.strip}/#{query_type}"

      begin
        uri = URI(URI.encode(load_balancer_address))

        req = Net::HTTP::Post.new(uri)
        req.set_form_data(address: "localhost:#{port}", name: 'ExperimentManager')

        if scheme == 'https'
          ssl_options = {use_ssl: true, ssl_version: :SSLv3, verify_mode: OpenSSL::SSL::VERIFY_NONE}
        else
          ssl_options = {}
        end
        response = Net::HTTP.start(uri.host, uri.port, ssl_options) { |http| http.request(req) }

        puts "Load balancer message: #{response.body}"
      rescue StandardError, Timeout::Error => e
        puts "Registration to load balancer failed: #{e.message}"
        raise
      end
    end

  end

  def self.register
    self.load_balancer_query 'register'
  end

  def self.unregister
    self.load_balancer_query 'unregister'
  end

end