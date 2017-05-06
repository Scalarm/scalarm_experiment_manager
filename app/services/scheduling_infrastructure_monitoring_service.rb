class SchedulingInfrastructureMonitoringService

  def initialize(infrastructure_id, user_id, time_delay)
    Rails.logger.info("[SchedulingInfrastructureMonitoringService] INIT infra: #{infrastructure_id}, user: #{user_id}, delay: #{time_delay}")

    @infrastructure_id = infrastructure_id.to_s
    @user_id = user_id.to_s
    @time_delay = time_delay
  end

  def run
    Rails.logger.info("[SchedulingInfrastructureMonitoringService] RUN infra: #{@infrastructure_id}, user: #{@user_id}, delay: #{@time_delay}")

    Scalarm::MongoLock.mutex("user-#{@user_id}-monitoring") do
      user = ScalarmUser.where(id: @user_id).first
      Rails.logger.info("User: #{user}")

      unless user.monitoring_scheduled?(@infrastructure_id)
        Rails.logger.info("Scheduling another SimMonitorWorker - #{@infrastructure_id} - #{@user_id}")

        if @time_delay.nil?
          Rails.logger.info("[SchedulingInfrastructureMonitoringService] ASYNC infra: #{@infrastructure_id}, user: #{@user_id}, delay: #{@time_delay}")
          SimMonitorWorker.perform_async(@infrastructure_id, @user_id)
        else
          Rails.logger.info("[SchedulingInfrastructureMonitoringService] DELAY infra: #{@infrastructure_id}, user: #{@user_id}, delay: #{@time_delay}")
          SimMonitorWorker.perform_in(@time_delay, @infrastructure_id, @user_id)
        end

        user.set_monitoring_scheduled(@infrastructure_id)
        user.save
        Rails.logger.info("User after setting: #{user}")
      else
        Rails.logger.info("There is no need to schedule another SimMonitorWorker - #{@infrastructure_id} - #{@user_id}")
      end
    end
  end

end