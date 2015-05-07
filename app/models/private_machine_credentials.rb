# Fields:
# host: ip/dns address of the machine
# port
# user_id: ScalarmUser id who has this secrets
#
# login: ssh login
# secret_password: ssh password
#
# other fields are user defined and should be of String class to enable encryption!

require 'scalarm/database/model/private_machine_record'

class PrivateMachineCredentials < Scalarm::Database::Model::PrivateMachineCredentials
  include SSHEnabledRecord

  attr_join :user, ScalarmUser

  SSH_AUTH_METHODS = %w(password)

  def ssh_params
    {
        port: port.to_i, password: secret_password,
        auth_methods: SSH_AUTH_METHODS, timeout: 15
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