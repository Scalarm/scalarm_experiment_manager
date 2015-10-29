# Fields:
# host: ip/dns address of the machine
# port
# user_id: ScalarmUser id who has this secrets
#
# login: ssh login
# secret_password: ssh password
#
# other fields are user defined and should be of String class to enable encryption!

class PrivateMachineCredentials < EncryptedMongoActiveRecord
  include SSHEnabledRecord

  SSH_AUTH_METHODS = %w(password)

  attr_join :user, ScalarmUser

  def self.collection_name
    'private_machine_credentials'
  end

  def machine_desc
    "#{login}@#{host}:#{port}"
  end

  def ssh_params
    {
        port: port.to_i, password: secret_password, timeout: 15
    }
  end

  def valid?
    begin
      ssh_session {}
      true
    rescue
      false
    end
  end

  private # -------

  def _get_ssh_session
    Net::SSH.start(host, login, ssh_params)
  end

  def _get_scp_session
    Net::SCP.start(host, login, ssh_params)
  end

end