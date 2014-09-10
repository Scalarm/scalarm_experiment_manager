require 'net/http'
require 'socket'
require 'ipaddr'
require 'openssl'

if ENV['LOAD_BALANCER'] != '' or ENV['LOAD_BALANCER'] != 'true'
  ENV['LOAD_BALANCER'] = 'true'

  MULTICAST_ADDR = '224.1.2.3'
  PORT = 8000
  BIND_ADDR = '0.0.0.0'

  socket = UDPSocket.new
  membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

  socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
  #socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

  socket.bind(BIND_ADDR, PORT)

  message, _ = socket.recvfrom(20)
  #load_balancer_address = "https://#{message.strip}/register"
  load_balancer_address = "https://#{message.strip}/experiment_managers/register"
  puts "Registration to load balancer: #{load_balancer_address}"
  port = '3000'

  if defined? ENV['PORT'] and ENV['PORT'] != nil and ENV['PORT'] != ''
    port = "#{ENV['PORT']}"
  end
  puts "Port #{port}"
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  #Net::HTTP.post_form(URI.parse(URI.encode(load_balancer_address)),
  #                    {'address'=> "localhost:#{port}"})

  uri = URI.parse(URI.encode(load_balancer_address))

  req = Net::HTTP::Post.new(uri)
  req.set_form_data('address'=> "localhost:#{port}")
  req.basic_auth 'scalarm', 'scalarm'

  res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') {|http|
    http.request(req)
  }
  puts res.body

end