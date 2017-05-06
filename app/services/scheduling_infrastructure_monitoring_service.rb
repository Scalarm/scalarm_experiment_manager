class SchedulingInfrastructureMonitoringService

  def initialize(infrastructure_id, user_id, time_delay)
    @infrastructure_id = infrastructure_id.to_s
    @user_id = user_id.to_s
    @time_delay = time_delay
  end

  def run
    Scalarm::MongoLock.mutex("user-#{@user_id}-monitoring") do
      user = ScalarmUser.where(id: @user_id).first

      unless user.monitoring_scheduled?(@infrastructure_id)
        if @time_delay.nil?
          SimMonitorWorker.perform_async(@infrastructure_id, @user_id)
        else
          SimMonitorWorker.perform_in(@time_delay, @infrastructure_id, @user_id)
        end

        user.set_monitoring_scheduled(@infrastructure_id)
        user.save
      end
    end
  end

end