require 'net/http'
require 'socket'
require 'ipaddr'
require 'openssl'

unless Rails.application.secrets.disable_load_balancer_registration
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

    load_balancer_address = "https://#{message.strip}/experiment_managers/register"
    uri = URI.parse(URI.encode(load_balancer_address))
    req = Net::HTTP::Post.new(uri)
    req.set_form_data('address' => "localhost:#{port}")
    req.basic_auth 'scalarm', 'scalarm'

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') { |http| http.request(req) }
      puts "Load balancer message: #{res.body}"
    rescue StandardError, Timeout::Error => e
      puts "Registration to load balancer failed: #{e.message}"
    end
  end

end
