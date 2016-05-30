require 'singleton'
require 'infrastructure_facades/slurm_scheduler'
require 'infrastructure_facades/pbs_scheduler'
require 'infrastructure_facades/infrastructure_task_logger'

class SchedulerFactory
  include Singleton

  def get_scheduler(scheduler_name)
    case scheduler_name
      when 'slurm'
        SlurmScheduler.new
      when 'pbs'
        PbsScheduler.new
      else
        nil
    end
  end
end
