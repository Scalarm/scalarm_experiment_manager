# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn
require 'grid-proxy'

class ScalarmUser < MongoActiveRecord

  def self.collection_name
    'scalarm_users'
  end

  def experiments
    Experiment.visible_to(self)
  end

  def simulation_scenarios
    Simulation.visible_to(self)
  end

  def owned_experiments
    Experiment.where(user_id: id)
  end

  def get_running_experiments
    experiments.where(is_running: true)
  end

  def get_historical_experiments
    experiments.where(is_running: false)
  end

  # returns simulation scenarios owned by this user or shared with this user
  def get_simulation_scenarios
    Simulation.where({'$or' => [
        {user_id: self.id}, {shared_with: {'$in' => [self.id]}}, {is_public: true}]}).sort { |s1, s2|
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
    user = ScalarmUser.find_by_login(login.to_s)

    if user.nil? || user.password_salt.nil? || user.password_hash.nil?  || Digest::SHA256.hexdigest(password + user.password_salt) != user.password_hash
      raise I18n.t('user_controller.login.bad_login_or_pass')
    end

    user
  end

  def self.authenticate_with_certificate(dn)
    # backward-compatibile: there are some dn's formatted by PL-Grid OpenID in database - try to convert
    # TODO: migrate database to proper DN's
    user = (ScalarmUser.find_by_dn(dn.to_s) or
        ScalarmUser.find_by_dn(PlGridOpenID.browser_dn_to_plgoid_dn(dn)))

    if user.nil?
      raise "Authentication failed: user with DN = #{dn} not found"
    end

    user
  end

  # Arguments:
  # - proxy - GP::Proxy or String containing proxy certificate
  def self.authenticate_with_proxy(proxy, verify=true)
    proxy = (proxy.is_a?(GP::Proxy) ? proxy : GP::Proxy.new(proxy))
    ScalarmUser.where(login: proxy.username).first if !verify or proxy.valid_for_plgrid?
  end

  def grid_credentials
    GridCredentials.find_by_user_id(id.to_s)
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

  def self.get_anonymous_user
    @anonymous_user ||= ScalarmUser.find_by_login(Utils::load_config['anonymous_login'].to_s)
  end

  def destroy_unused_credentials
    InfrastructureFacadeFactory.get_all_infrastructures.each do |infrastructure_facade|
      infrastructure_facade.destroy_unused_credentials(:x509_proxy, self)
    end
  end

  private

  def compute_ban_end(start_time)
    start_time + 5.minutes
  end

end