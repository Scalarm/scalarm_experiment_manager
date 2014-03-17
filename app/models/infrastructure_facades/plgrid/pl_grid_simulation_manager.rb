require 'net/ssh'
require 'infrastructure_facades/abstract_simulation_manager'

class PlGridSimulationManager < AbstractSimulationManager
  attr_reader :logger
  attr_reader :ssh_session

  class NoCredentialsError < StandardError; end

  def initialize(plgrid_job_record, ssh_session=nil)
    super(plgrid_job_record)
    @ssh_session = ssh_session
    @logger = InfrastructureTaskLogger.new('plgrid', record.job_id)
  end

  def monitor
    use_ssh do |ssh|
      logger.info 'checking'
      ssh.exec!('voms-proxy-init --voms vo.plgrid.pl') if record.scheduler_type == 'glite' # generate new proxy if glite

      logger.debug "Experiment: #{record.experiment_id} --- nil?: #{experiment.nil?}"

      if experiment_end?
        logger.info "Experiment '#{experiment.id}' is no longer running => destroy the job and temp password"
        destroy_and_clean_after(ssh)

      elsif init_time_exceeded?(ssh)
        logger.info 'The job will be restarted due to not been run'
        scheduler.restart(ssh, record)

      elsif max_time_exceeded?
        logger.info 'The job will be restarted due to being run for 24 hours'
        scheduler.restart(ssh, record)

      elsif time_limit_exceeded?
        logger.info 'This job is going to be destroyed due to time limit'
        stop

      elsif job_done?(ssh)
        logger.info 'The job is done - so we will destroy it'
        stop
      end
    end
  end

  def stop
    use_ssh do |ssh|
      scheduler.cancel(ssh, record)
      destroy_and_clean_after(ssh)
    end
  end

  def restart
    logger.info 'The job will be restarted on users\'s demand'
    use_ssh do |ssh|
      scheduler.restart(ssh, record)
    end
  end

  def job_status
    use_ssh do |ssh|
      raise NotImplementedError
    end
  end

  # --

  def scheduler
    @scheduler ||= PlGridFacade.create_scheduler_facade(record.scheduler_type)
  end

  # ----

  private

  # -- monitoring cases --

  #  if the job is not running although it should (create_at + 10.minutes > Time.now) - restart = cancel + start
  def init_time_exceeded?(ssh)
    scheduler.is_job_queued(ssh, record) and (record.created_at + record.max_init_time < Time.now)
  end

  #  if the job is running more than 24 h then restart
  def max_time_exceeded?
    record.created_at + 24.hours < Time.now
  end

  def time_limit_exceeded?
    record.created_at + record.time_limit.minutes < Time.now
  end

  def job_done?(ssh)
    scheduler.is_done(ssh, record)
  end

  # -- monitoring utils --

  def destroy_and_clean_after(ssh)
    logger.info "Destroying temp pass for #{record.sm_uuid}"
    temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(record.sm_uuid)
    logger.info "It is nil ? --- #{temp_pass.nil?}"
    temp_pass.destroy unless temp_pass.nil? || temp_pass.longlife
    record.destroy
    scheduler.clean_after_job(ssh, record)
  end

  # -- utils --

  def use_ssh
    if ssh_session.nil?
      credentials = GridCredentials.find_by_user_id(record.user_id)
      raise NoCredentialsError("PL-Grid, for user_id: #{user_id} in job_id: #{job_id}") if credentials.nil?

      logger.info 'starting new ssh session'
      Net::SSH.start(credentials.host, credentials.login,
                     password: credentials.password) do |ssh|
        yield ssh
      end
    else
      logger.debug 'using existing ssh session'
      yield ssh_session
    end
  end

  def credentials

  end

end
