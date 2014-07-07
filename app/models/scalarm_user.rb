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

  # returns simulation scenarios owned by this user or shared with this user
  def get_simulation_scenarios
    Simulation.where({ '$or' => [
      { user_id: self.id }, { shared_with: { '$in' => [ self.id ] } }, { is_public: true} ] }).sort { |s1, s2|
      s2.created_at <=> s1.created_at }
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

  def grid_credentials
    GridCredentials.find_by_user_id(id)
  end

  def banned_infrastructure?(infrastructure_name)
    if credentials_failed and credentials_failed.include?(infrastructure_name) and
        credentials_failed[infrastructure_name].count >= 2 and (compute_ban_end(credentials_failed[infrastructure_name].last) > Time.now)
      true
    else
      false
    end
  end

  def ban_expire_time(infrastructure_name)
    if credentials_failed and credentials_failed[infrastructure_name] and credentials_failed[infrastructure_name].count > 0
      compute_ban_end(credentials_failed[infrastructure_name].last)
    else
      nil
    end
  end

  private

  def compute_ban_end(start_time)
    start_time + 5.minutes
  end

end