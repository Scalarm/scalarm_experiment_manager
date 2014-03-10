# Subclasses must implement:
# - short_name() -> String
# - long_name() -> String

require 'infrastructure_facades/plgrid/scheduled_pl_grid_job'

class PLGridSchedulerBase
  include ScheduledJobsContainter

  def scheduled_jobs(user_id)
    jobs = PlGridJob.find_all_by_query('scheduler_type'=>short_name, 'user_id'=>user_id)
    secrets = GridCredentials.find_by_user_id(user_id)
    secrets.nil? ? [] : jobs.map { |r| ScheduledPLGridJob.new(r) } # TODO: use secrets
  end

end