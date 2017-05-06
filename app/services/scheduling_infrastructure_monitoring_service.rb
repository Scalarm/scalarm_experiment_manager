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
        Rails.logger.info("Scheduling another SimMonitorWorker - #{@infrastructure_id} - #{@user_id}")

        if @time_delay.nil?
          SimMonitorWorker.perform_async(@infrastructure_id, @user_id)
        else
          SimMonitorWorker.perform_in(@time_delay, @infrastructure_id, @user_id)
        end

        user.set_monitoring_schedule(@infrastructure_id)
        user.save
      else
        Rails.logger.info("There is no need to schedule another SimMonitorWorker - #{@infrastructure_id} - #{@user_id}")
      end
    end
  end

end