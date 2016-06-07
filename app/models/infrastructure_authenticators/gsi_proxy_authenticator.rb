require 'net/ssh'
require 'gsi/ssh'

class GsiProxyAuthenticator

	def initialize(credentials)
		@credentials = credentials
	end

	def establish_ssh_session
	    # gsi_error = nil

	    begin
	      if @credentials.secret_proxy
	        return Gsi::SSH.start(@credentials.host, @credentials.login, @credentials.secret_proxy)
	      end
	    rescue Gsi::ProxyError => proxy_error
	      Rails.logger.debug "Proxy for PL-Grid user #{@credentials.login} is not valid: #{proxy_error.class}, removing"
	      @credentials.secret_proxy = nil
	      @credentials.save
	      raise
	      # gsi_error = proxy_error
	    rescue Gsi::ClientError => client_error
	      Rails.logger.warn "gsissh client error for PL-Grid user #{@credentials.login}: #{client_error}, removing"
	      @credentials.secret_proxy = nil
	      @credentials.save
	      raise
	      # gsi_error = client_error
	    end

	    # raise gsi_error
	end

	def establish_scp_session
      Gsi::SCP.start(@credentials.host, @credentials.login, @credentials.secret_proxy)
	end
	
end