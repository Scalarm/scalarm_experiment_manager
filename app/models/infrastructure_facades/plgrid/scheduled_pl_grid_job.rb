require 'infrastructure_facades/abstract_scheduled_job'

class ScheduledPLGridJob < AbstractScheduledJob
  attr_reader :logger

  def initialize(plgrid_job_record)
    super(plgrid_job_record)
    @logger = InfrastructureTaskLogger.new('plgrid', record.job_id)
  end

  # -- AbstractScheduledJob interface implementation --

  def name
    record.job_id
  end

  def monitor
    # TODO
    raise NotImplementedError
  end

  def stop
    # TODO
    raise NotImplementedError
  end

  def job_status
    # TODO
    raise NotImplementedError
  end

end
