# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn

class ScalarmUser < MongoActiveRecord

  def self.collection_name
    'scalarm_users'
  end

  def get_running_experiments
    Experiment.where({ '$or' => [
      { user_id: self.id }, { shared_with: { '$in' => [ self.id ] } } ] }).select do |experiment|
      experiment.is_running
    end
  end

  def get_historical_experiments
    Experiment.where({ '$or' => [
      { user_id: self.id }, { shared_with: { '$in' => [ self.id ] } } ] }).select do |experiment|
      experiment.is_running == false
    end
  end

  def get_simulation_scenarios
    Simulation.find_all_by_user_id(self.id).sort { |s1, s2| s2.created_at <=> s1.created_at }
  end

  def password=(pass)
    salt = [Array.new(6) { rand(256).chr }.join].pack('m').chomp
    self.password_salt, self.password_hash = salt, Digest::SHA256.hexdigest(pass + salt)
  end

  def owns?(experiment)
    id == experiment.user_id
  end

  def self.authenticate_with_password(login, password)
    user = ScalarmUser.find_by_login(login)

    if user.nil? || user.password_salt.nil? || user.password_hash.nil?  || Digest::SHA256.hexdigest(password + user.password_salt) != user.password_hash
      raise 'Bad login or password'
    end

    user
  end

  def self.authenticate_with_certificate(dn)
    user = ScalarmUser.find_by_dn(dn)

    if user.nil?
      raise "Authentication failed: user with DN = #{dn} not found"
    end

    user
  end

end