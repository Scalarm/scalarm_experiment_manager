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

  def self.collection_name
    'private_machine_secrets'
  end

  def machine_desc
    "#{login}@#{host}:#{ssh_port}"
  end

end