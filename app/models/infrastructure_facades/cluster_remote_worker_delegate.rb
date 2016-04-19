class ClusterRemoteWorkerDelegate
  attr_accessor :cluster_facade

  def initialize(scheduler)
    @scheduler = scheduler
  end

  def stop(sm_record)
    ssh = @cluster_facade.shared_ssh_session(sm_record.credentials)
    @scheduler.cancel(ssh, sm_record)
    @scheduler.clean_after_job(ssh, sm_record)
  end

  def restart(sm_record)
    ssh = @cluster_facade.shared_ssh_session(sm_record.credentials)
    @scheduler.restart(ssh, sm_record)
  end

  def resource_status(sm_record)
    ssh = nil

    begin
      ssh = @cluster_facade.shared_ssh_session(sm_record.credentials)
    rescue Exception => e
      # remember this error in case of unable to initialize
      sm_record.error_log = e.to_s
      sm_record.save
      return :not_available
    end

    begin
      job_id = sm_record.job_identifier
      if job_id
        status = @scheduler.status(ssh, sm_record)
        Rails.logger.info("Resource status: status: #{status} ")
        case status
          when :initializing then
            :initializing
          when :running then
            :running_sm
          when :deactivated then
            :released
          when :error then
            :released
          else
            Rails.logger.warn("Unknown state from cluster scheduler: #{status}")
            :error
        end
      else
        if sm_record.state == :terminating
          :released
        else
          :available
        end
      end
    rescue
      :error
    end
  end

  def get_log(sm_record)
    ssh = @cluster_facade.shared_ssh_session(sm_record.credentials)
    @scheduler.get_log(ssh, sm_record)
  end

  def prepare_resource(sm_record)
    sm_record.validate

    #  upload the code to the Grid user interface machine
    begin
      ssh = @cluster_facade.shared_ssh_session(sm_record.credentials)

      sm_uuid = sm_record.sm_uuid
      SSHAccessedInfrastructure::create_remote_directories(ssh)

      InfrastructureFacade.prepare_simulation_manager_package(sm_uuid, sm_record.user_id, sm_record.experiment_id, sm_record.start_at) do
        @scheduler.create_tmp_job_files(sm_uuid, sm_record.to_h) do
          ssh.scp do |scp|
            @scheduler.send_job_files(sm_uuid, scp)
          end
        end
      end

      begin
        sm_record.job_identifier = @scheduler.submit_job(ssh, sm_record)
        sm_record.save
      rescue JobSubmissionFailed => job_failed
        Rails.logger.warn "Scheduling job failed: #{job_failed.to_s}"
        sm_record.store_error('install_failed', job_failed.to_s)
      end

    rescue Net::SSH::AuthenticationFailed => auth_exception
      Rails.logger.error "Authentication failed when starting simulation managers for user #{sm_record.user_id}: #{auth_exception.to_s}"
      sm_record.store_error('ssh')
    rescue Exception => ex
      Rails.logger.error "Exception when starting simulation managers for user #{sm_record.user_id}: #{ex.to_s}\n#{ex.backtrace.join("\n")}"
      sm_record.store_error('install_failed', "#{ex.to_s}\n#{ex.backtrace.join("\n")}")
    end
  end

end
