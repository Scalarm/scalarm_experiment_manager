# MongoActiveRecord with automatic encrypt/decrypt
# for all attributes with 'secret_' prefix when using setters/getters
# Important: when using constructor to set attributes, e.g.
# EncryptedMongoActiveRecord.new({'secret_login'=>'my_login'}), the attribute IS NEVER encrypted
# to encrypt attribute use:
# record = EncryptedMongoActiveRecord.new({})
# record.secret_password = 'my_password'
# record.save
class EncryptedMongoActiveRecord < MongoActiveRecord

  def to_h
    super.select {|k, v| !(k =~ /secret_.*/)}
  end

  # this method should be overriden and provide array of attributes which will not be encrypted
  def self.encryption_excluded
    []
  end

  # handling getters and setters for object instance with encryption on-the-fly
  def method_missing(method_name, *args, &block)
    use_encryption = false
    method_name = method_name.to_s

    # encrypt only attributes starting with 'secret_'
    if method_name.start_with?('secret_')
      use_encryption = true
    end

    setter = false
    if method_name.ends_with? '='
      method_name.chop!
      setter = true

      # cannot encrypt type other than String
      if args.first.class != String
        use_encryption = false
      end
    end

    method_name = '_id' if method_name == 'id'

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
          # this should not be used normally...
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