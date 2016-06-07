require 'net/ssh'

class BasicAuthAuthenticator

	def initialize(credentials)
		@credentials = credentials
	end

	def establish_ssh_session
		Net::SSH.start(@credentials.cluster.host, @credentials.login, 
			password: @credentials.secret_password, auth_methods: %w(keyboard-interactive password))
	end

	def establish_scp_session
		Net::SCP.start(@credentials.cluster.host, @credentials.login, 
			password: @credentials.secret_password, auth_methods: %w(keyboard-interactive password))
	end

end