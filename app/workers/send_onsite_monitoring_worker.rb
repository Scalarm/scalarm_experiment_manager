class SendOnsiteMonitoringWorker
  include Sidekiq::Worker

  def perform(infrastructure_class, record_ids, credentials_id, user_id, scheduler_name, params)
    infrastructure = Object.const_get(infrastructure_class)
    records = infrastructure.sm_record_class.all.to_a.select{|sm| record_ids.include?(sm.id)}
    credentials = infrastructure.credentials_record_class.where(id: credentials_id).first
    sm_uuid = SecureRandom.uuid

    InfrastructureFacade.handle_monitoring_send_errors(records) do
      infrastructure.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, scheduler_name, params)
    end
  end

end

