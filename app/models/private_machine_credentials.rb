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

  SSH_AUTH_METHODS = %w(password)

  def self.collection_name
    'private_machine_credentials'
  end

  def machine_desc
    "#{login}@#{host}:#{port}"
  end

  def upload_file(local_path, remote_path='.')
    Net::SCP.start(host, login, port: port.to_i, password: secret_password,
                   auth_methods: SSH_AUTH_METHODS) do |scp|
      scp.upload! local_path, remote_path
    end
  end

  def ssh_start
    Net::SSH.start(host, login, port: port.to_i, password: secret_password,
                   auth_methods: SSH_AUTH_METHODS, timeout: 30) do |ssh|
      yield ssh
    end
  end

end