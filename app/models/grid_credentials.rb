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

class GridCredentials < EncryptedMongoActiveRecord
  include SSHEnabledRecord

  @@CIPHER_NAME = 'aes-256-cbc'
  @@CIPHER_KEY = "tC\x7F\x9Er\xA6\xAFU\x88\x19\x9B\x0F\xDD\x88O]6\xA0\xAD\x8B\xBF,4\x06<\xC0[\x03\xC7\x11\x90\x10"
  @@CIPHER_IV = "\xA9\x8E\xD0\x031 w0\x1Ed\xEC\xC4\xD4\xEA\x87\e"

  attr_join :user, ScalarmUser

  def self.collection_name
    'grid_credentials'
  end

  def password
    if hashed_password
      decipher = GridCredentials::decipher
      password = decipher.update(Base64.strict_decode64(self.hashed_password))
      password << decipher.final

      password
    else
      nil
    end
  end

  def password=(new_password)
    cipher = GridCredentials::cipher
    encrypted_password = cipher.update(new_password)
    encrypted_password << cipher.final
    encrypted_password = Base64.strict_encode64(encrypted_password)

    self.hashed_password = encrypted_password
  end

  def valid?
    begin
      ssh_session {}
      true
    rescue Exception
      false
    end
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
      Net::SSH.start(host, login, password: password)
    else
      raise (gsi_error or InfrastructureErrors::NoCredentialsError)
    end
  end

  def host
    get_attribute('host') or 'ui.cyfronet.pl'
  end

  # -----------
  private

  def _get_scp_session
    if secret_proxy
      Gsi::SCP.start(host, login, secret_proxy)
    elsif password
      Net::SCP.start(host, login, password: password)
    else
      raise InfrastructureErrors::NoCredentialsError
    end
  end

  def self.cipher
    cipher = OpenSSL::Cipher::Cipher.new(@@CIPHER_NAME)
    cipher.encrypt
    cipher.padding = 1
    cipher.key = @@CIPHER_KEY
    cipher.iv = @@CIPHER_IV

    cipher
  end

  def self.decipher
    decipher = OpenSSL::Cipher::Cipher.new(@@CIPHER_NAME)
    decipher.decrypt
    decipher.key = @@CIPHER_KEY
    decipher.iv = @@CIPHER_IV

    decipher
  end

end
