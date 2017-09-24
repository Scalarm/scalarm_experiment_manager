class UnsetSchedulingInfrastructureMonitoringService

  def initialize(infrastructure_id, user_id)
    @infrastructure_id = infrastructure_id.to_s
    @user_id = user_id.to_s
  end

  def run
    return if @user_id.blank?

    Scalarm::MongoLock.mutex("user-#{@user_id}-monitoring") do
      Rails.logger.info("Unsetting infrastructure monitoring - #{@infrastructure_id} - #{@user_id}")
      user = ScalarmUser.where(id: @user_id).first
      user.unset_monitoring_schedule(@infrastructure_id)
      user.save
    end
  end

end
