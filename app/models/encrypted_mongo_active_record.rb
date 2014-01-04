# MongoActiveRecord with automatic encrypt/decrypt when using setters/getters
# Important: when using constructor to set attributes, e.g.
# EncryptedMongoActiveRecord.new({'login'=>'my_login'}), the attribute IS NOT encrypted
# to encrypt attribute use:
# record = EncryptedMongoActiveRecord.new({})
# record.password = 'secret_password'
# record.save
class EncryptedMongoActiveRecord < MongoActiveRecord
  Encryptor.default_options.merge!(:key => Digest::SHA256.hexdigest('QjqjFK}7|Xw8DDMUP-O$yp'))

  # handling getters and setters for object instance with encryption on-the-fly
  def method_missing(method_name, *args, &block)
    use_encryption = true

    #Rails.logger.debug("MongoRecord: #{method_name} - #{args.join(',')}")
    method_name = method_name.to_s; setter = false
    if method_name.ends_with? '='
      method_name.chop!
      setter = true

      # cannot encrypt type other than String
      if args.first.class != String
        use_encryption = false
      end
    end

    method_name = '_id' if method_name == 'id'

    # do not encrypt primary key and foreign keys
    if method_name.ends_with?('_id')
      use_encryption = false
    end

    if setter
      if use_encryption
        @attributes[method_name] = Base64.encode64(args.first.encrypt)
      else
        @attributes[method_name] = args.first
      end

    # getter
    elsif @attributes.include?(method_name)

      attribute = @attributes[method_name]
      use_encryption = false if attribute.class != String

      if use_encryption
        begin
          Base64.decode64(attribute).decrypt
        rescue OpenSSL::Cipher::CipherError
          attribute
        end
      else
        attribute
      end

    else
      nil
      #super(method_name, *args, &block)
    end
  end
end