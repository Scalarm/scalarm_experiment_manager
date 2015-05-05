# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn
require 'grid-proxy'

require 'scalarm/database/model/scalarm_user'

class ScalarmUser < Scalarm::Database::Model::ScalarmUser

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