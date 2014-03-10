require 'net/ssh'
require 'infrastructure_facades/abstract_simulation_manager'

class PlGridSimulationManager < AbstractSimulationManager
  attr_reader :logger
  attr_reader :ssh

  def initialize(plgrid_job_record, ssh=nil)
    super(plgrid_job_record)
    @ssh = ssh
    @logger = InfrastructureTaskLogger.new('plgrid', record.job_id)
  end

  # -- AbstractScheduledJob interface implementation --

  def name
    record.job_id
  end

  def monitor
    logger.info 'checking'
    ssh.exec!('voms-proxy-init --voms vo.plgrid.pl') if record.scheduler_type == 'glite' # generate new proxy if glite

    logger.debug "Experiment: #{record.experiment_id} --- nil?: #{experiment.nil?}"

    if experiment_end?
      logger.info "Experiment '#{experiment.id}' is no longer running => destroy the job and temp password"
      destroy_and_clean_after

    elsif init_time_exceeded?
      logger.info 'The job will be restarted due to not been run'
      scheduler.restart(ssh, record)

    elsif max_time_exceeded?
      logger.info 'The job will be restarted due to being run for 24 hours'
      scheduler.restart(ssh, record)

    elsif time_limit_exceeded?
      logger.info 'This job is going to be destroyed due to time limit'
      stop

    elsif job_done?
      logger.info 'The job is done - so we will destroy it'
      stop
    end

  end

  def stop
    scheduler.cancel(ssh, record)
    destroy_and_clean_after
  end

  def job_status
    # TODO
    raise NotImplementedError
  end

  # -- monitoring cases --

  #  if the job is not running although it should (create_at + 10.minutes > Time.now) - restart = cancel + start
  def init_time_exceeded?
    scheduler.is_job_queued(ssh, record) and (record.created_at + record.max_init_time < Time.now)
  end

  #  if the job is running more than 24 h then restart
  def max_time_exceeded?
    record.created_at + 24.hours < Time.now
  end

  def time_limit_exceeded?
    record.created_at + record.time_limit.minutes < Time.now
  end

  def job_done?
    scheduler.is_done(ssh, record)
  end

  # -- monitoring utils --

  def destroy_and_clean_after
    logger.info "Destroying temp pass for #{record.sm_uuid}"
    temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(record.sm_uuid)
    logger.info "It is nil ? --- #{temp_pass.nil?}"
    temp_pass.destroy unless temp_pass.nil? || temp_pass.longlife
    record.destroy
    scheduler.clean_after_job(ssh, record)
  end

  # -- utils --

  def scheduler
    @scheduler ||= PlGridFacade.create_scheduler_facade(record.scheduler_type)
  end

end
