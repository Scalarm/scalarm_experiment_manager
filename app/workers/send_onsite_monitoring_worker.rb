class SendOnsiteMonitoringWorker
  include Sidekiq::Worker

  def perform(infrastructure, records, credentials, user_id, scheduler_name, params)
    sm_uuid = SecureRandom.uuid

    InfrastructureFacade.handle_monitoring_send_errors(records) do
      infrastructure.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, scheduler_name, params)
    end
  end

end

