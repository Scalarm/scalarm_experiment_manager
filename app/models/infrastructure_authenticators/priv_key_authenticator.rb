require 'net/ssh'

class PrivKeyAuthenticator

	def initialize(credentials)
		@credentials = credentials
	end

	def establish_ssh_session
      privkey_file = Tempfile.new(@credentials.owner_id.to_s)
      privkey_file.write(@credentials.secret_privkey)
      privkey_file.close

      ssh = nil
      begin
        ssh = Net::SSH.start(@credentials.cluster.host, @credentials.login, 
        	keys: [ privkey_file.path ], auth_methods: %w(publickey))
      ensure
        privkey_file.unlink
      end

      ssh
	end

	def establish_scp_session
      privkey_file = Tempfile.new(@credentials.owner_id.to_s)
      privkey_file.write(@credentials.secret_privkey)
      privkey_file.close

      scp = nil
      begin
        scp = Net::SCP.start(@credentials.cluster.host, @credentials.login, 
        	keys: [ privkey_file.path ], auth_methods: %w(publickey))
      ensure
        privkey_file.unlink
      end

      scp
	end
	
end