require 'singleton'
require 'infrastructure_facades/slurm_scheduler'
require 'infrastructure_facades/infrastructure_task_logger'

class SchedulerFactory
  include Singleton

  def get_scheduler(scheduler_name)
    if scheduler_name == 'slurm'
      SlurmScheduler.new
    else
      nil
    end
  end
end
