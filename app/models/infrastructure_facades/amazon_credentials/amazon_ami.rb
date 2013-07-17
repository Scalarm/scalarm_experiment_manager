# Fields:
# user_id: ScalarmUser id who has this secrets
# experiment_id: id of an experiment, which can be run with this AMI
# ami_id: id of an Amazon Cloud image
# login: user login who can access this ami
# password: actually stored as hash_password

class AmazonAmi < MongoActiveRecord

  def self.collection_name
    'amazon_amis'
  end

  def password
    Base64.decode64(self.hashed_password).decrypt
  end

  def password=(new_password)
    self.hashed_password = Base64.encode64(new_password.encrypt)
  end

end