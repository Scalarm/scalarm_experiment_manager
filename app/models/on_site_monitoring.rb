# Attributes
# - user_id
# - infrastructure
# - sm_uuid
# - last_ping

class OnSiteMonitoring < MongoActiveRecord
  attr_join :user, ScalarmUser

  def self.collection_name
    'on_site_monitorings'
  end

  def temp_password
    SimulationManagerTempPassword.where(sm_uuid: self.sm_uuid).first
  end

  # Checks if associated Monitoring pinged recently
  # TODO: max last ping time from configuration
  def pinged_recently?
    self.last_ping and (self.last_ping+2.minutes > Time.now)
  end

  def destroy
    tp = temp_password
    tp.destroy if tp
    super
  end
end