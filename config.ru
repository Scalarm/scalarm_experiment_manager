# This file is used by Rack-based servers to start the application.
require ::File.expand_path('../config/environment',  __FILE__)

run SimulationManager::Application
# 
# handler = Rack::Handler::Thin
# handler.run(app) do |server| 
#   host = ""
#   require 'socket'; UDPSocket.open{|s| s.connect('64.233.187.99', 1); host = s.addr.last}
#   puts "AAA --- #{host} --- #{server.backend.port}"
# end
