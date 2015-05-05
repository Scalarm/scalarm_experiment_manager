# Fields:
# - user_id
# - login
# - password (not needed if has secret_proxy)
# - secret_proxy (not needed if has password)

require 'openssl'
require 'base64'

require 'net/ssh'
require 'gsi/ssh'

require 'infrastructure_facades/infrastructure_errors'

require 'scalarm/database/model/grid_credentials'

class GridCredentials < Scalarm::Database::Model::GridCredentials
  include SSHEnabledRecord

  # Exclude also hashed password field
  def to_h
    super.select {|k, v| k != 'hashed_password'}
  end

  def valid?
    begin
      ssh_session {}
      true
    rescue Exception
      false
    end
  end

  def host
    get_attribute('host') or 'ui.cyfronet.pl'
  end

  def _get_ssh_session
    gsi_error = nil
    begin
      if secret_proxy
        return Gsi::SSH.start(host, login, secret_proxy)
      end
    rescue Gsi::ProxyError => proxy_error
      Rails.logger.debug "Proxy for PL-Grid user #{login} is not valid: #{proxy_error.class}, removing"
      self.secret_proxy = nil
      self.save
      gsi_error = proxy_error
    rescue Gsi::ClientError => client_error
      Rails.logger.warn "gsissh client error for PL-Grid user #{login}: #{client_error}"
      gsi_error = client_error
    end

    if password
      Net::SSH.start(host, login, password: password, auth_methods: %w(keyboard-interactive password))
    else
      raise (gsi_error or InfrastructureErrors::NoCredentialsError)
    end
  end

  def _get_scp_session
    if secret_proxy
      Gsi::SCP.start(host, login, secret_proxy)
    elsif password
      Net::SCP.start(host, login, password: password, auth_methods: %w(keyboard-interactive password))
    else
      raise InfrastructureErrors::NoCredentialsError
    end
  end

end
