require 'net/http'
require 'socket'
require 'ipaddr'
require 'openssl'

unless Rails.env.test? or Rails.application.secrets.disable_load_balancer_registration
  unless Rails.application.secrets.include? :multicast_address
    raise StandardError.new("multicast_address is missing in secrets configuration")
  end
  MULTICAST_ADDR, PORT  = Rails.application.secrets[:multicast_address].split(':')
  BIND_ADDR = '0.0.0.0'
  message = 'error'
  begin
    socket = UDPSocket.new
    membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

    socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
    socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

    socket.bind(BIND_ADDR, PORT)
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

  if message != 'error'
    port = (Rails.application.secrets[:port] or '3000')
    scheme = 'https'
    if Rails.application.secrets.load_balancer_development
      scheme = 'http'
    end
    load_balancer_address = "#{scheme}://#{message.strip}/register"

    begin
      uri = URI(URI.encode(load_balancer_address))

      req = Net::HTTP::Post.new(uri)
      req.set_form_data(address: "localhost:#{port}", name: 'ExperimentManager')

      if scheme == 'https'
        ssl_options = { use_ssl: true, ssl_version: :SSLv3, verify_mode: OpenSSL::SSL::VERIFY_NONE }
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
