require 'openssl'
require 'base64'

# Fields:
# user_id: ScalarmUser id who has this secrets
# login: login for PLCloud rest service
# password: password for PLCloud rest service

class PLCloudSecrets < MongoActiveRecord
  @@CIPHER_NAME = 'aes-256-cbc'
  @@CIPHER_KEY = "tC\x7F\x9Er\xA6\xAFU\x88\x19\x9B\x0F\xDD\x88O]6\xA0\xAD\x8B\xBF,4\x06<\xC0[\x03\xC7\x11\x90\x10"
  @@CIPHER_IV = "\xA9\x8E\xD0\x031 w0\x1Ed\xEC\xC4\xD4\xEA\x87\e"

  def self.collection_name
    'pl_cloud_secrets'
  end

  def password
    decipher = PLCloudSecrets::decipher
    password = decipher.update(Base64.strict_decode64(self.hashed_password))
    password << decipher.final

    password
  end

  def password=(new_password)
    cipher = PLCloudSecrets::cipher
    encrypted_password = cipher.update(new_password)
    encrypted_password << cipher.final
    encrypted_password = Base64.strict_encode64(encrypted_password)

    self.hashed_password = encrypted_password
  end

  private

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
