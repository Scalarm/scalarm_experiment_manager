##
# Represents credentials to a remote cluster
# ==== Fields:
# owner:: user_id
# cluster:: cluster_record_id
# type:: either 'password' or 'privkey'
# login:: string - login to the cluster required if type == 'password'
# secret_password:: string - password to the cluster required if type == 'password'
# secret_private_key:: string - private key the cluster required if type == 'privkey'

require 'net/ssh'
require 'scalarm/database/core/encrypted_mongo_active_record'
require 'infrastructure_facades/infrastructure_errors'

class ClusterCredentials < Scalarm::Database::EncryptedMongoActiveRecord
  include SSHEnabledRecord

  use_collection 'cluster_credentials'

  attr_join :owner, ScalarmUser
  attr_join :cluster, ClusterRecord

  def valid?
    begin
      ssh_session {}
      true
    rescue Exception
      false
    end
  end

  def _get_ssh_session
    if type == 'password'
      return Net::SSH.start(cluster.host, login, password: secret_password, auth_methods: %w(keyboard-interactive password))
    end

    raise InfrastructureErrors::NoCredentialsError
  end

  def _get_scp_session
    if type == 'password'
      return Net::SCP.start(cluster.host, login, password: secret_password, auth_methods: %w(keyboard-interactive password))
    end

    raise InfrastructureErrors::NoCredentialsError
  end

  def self.create_password_credentials(user_id, cluster_id, login, password)
    if login.blank? or password.blank?
      raise StandardError.new('Provided login or password is blank')
    end

    creds = ClusterCredentials.new({login: login, type: 'password', owner_id: user_id, cluster_id: cluster_id})
    creds.secret_password = password
    creds
  end

  def self.create_privkey_credentials(user_id, cluster_id, privkey)
    if privkey.blank?
      raise StandardError.new('Provided privkey is blank')
    end

    creds = ClusterCredentials.new({login: login, type: 'privkey', owner_id: user_id, cluster_id: cluster_id})
    creds.secret_privkey = privkey
    creds
  end

end
