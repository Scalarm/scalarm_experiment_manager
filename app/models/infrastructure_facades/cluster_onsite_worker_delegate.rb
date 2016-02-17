class ClusterOnsiteWorkerDelegate

  def initialize(scheduler)
    @scheduler = scheduler
  end

  def stop(sm_record)
    if sm_record.cmd_to_execute_code.blank?
      sm_record.cmd_to_execute_code = "stop"
      sm_record.cmd_to_execute = BashCommand.new.
                                    append(@scheduler.cancel_sm_cmd(sm_record)).
                                    append(@scheduler.clean_after_sm_cmd(sm_record)).to_s
      sm_record.cmd_delegated_at = Time.now
      sm_record.save
    end
  end

  def restart(sm_record)
    sm_record.cmd_to_execute_code = 'restart'
    sm_record.cmd_to_execute = @scheduler.restart_sm_cmd(sm_record).to_s
    sm_record.cmd_delegated_at = Time.now
    sm_record.save
  end

  def resource_status(sm_record)
    sm_record.resource_status || :not_available
  end

  def get_log(sm_record)
    sm_record.cmd_to_execute_code = "get_log"
    sm_record.cmd_to_execute = @scheduler.get_log_cmd(sm_record).to_s
    sm_record.cmd_delegated_at = Time.now
    sm_record.save

    nil
  end

  def prepare_resource(sm_record)
    sm_record.cmd_to_execute_code = "prepare_resource"
    sm_record.cmd_to_execute = @scheduler.submit_job_cmd(sm_record).to_s
    sm_record.cmd_delegated_at = Time.now
    sm_record.save
  end

end
