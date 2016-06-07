##
# Represents credentials to a remote cluster
# ==== Fields:
# owner:: user_id
# cluster:: cluster_record_id
# type:: either 'password' or 'privkey' or 'gsiproxy'
# login:: string - login to the cluster required if type == 'password'
# secret_password:: string - password to the cluster required if type == 'password'
# secret_private_key:: string - private key the cluster required if type == 'privkey'
# secret_proxy:: string - X509 proxy certificate to the cluster required if type == 'gsiproxy'

require 'net/ssh'
require 'scalarm/database/core/encrypted_mongo_active_record'
require 'infrastructure_facades/infrastructure_errors'

require 'infrastructure_authenticators/basic_auth_authenticator'
require 'infrastructure_authenticators/priv_key_authenticator'
require 'infrastructure_authenticators/gsi_proxy_authenticator'

class ClusterCredentials < Scalarm::Database::EncryptedMongoActiveRecord
  include SSHEnabledRecord

  use_collection 'cluster_credentials'

  attr_join :owner, ScalarmUser
  attr_join :cluster, ClusterRecord

  def valid?
    begin
      ssh_session {}
      true
    rescue => e
      Rails.logger.error("Error occurred during credentials validation: #{e}")
      false
    end
  end

  def _get_ssh_session
    self.authenticator.establish_ssh_session
  end

  def _get_scp_session
    self.authenticator.establish_scp_session
  end

  def authenticator
    @authenticator ||= case self.type
      when 'password' then BasicAuthAuthenticator.new(self)
      when 'privkey' then PrivKeyAuthenticator.new(self)
      when 'gsiproxy' then GsiProxyAuthenticator.new(self)
      else raise InfrastructureErrors::NoCredentialsError
    end
  end

  def self.create_password_credentials(user_id, cluster_id, login, password)
    if login.blank? or password.blank?
      raise StandardError.new('Provided login or password is blank')
    end

    creds = ClusterCredentials.new({login: login, type: 'password', owner_id: user_id, cluster_id: cluster_id})
    creds.secret_password = password
    creds
  end

  def self.create_privkey_credentials(user_id, cluster_id, login, privkey)
    if privkey.blank?
      raise StandardError.new('Provided privkey is blank')
    end

    creds = ClusterCredentials.new({login: login, type: 'privkey', owner_id: user_id, cluster_id: cluster_id})
    creds.secret_privkey = privkey
    creds
  end

end
