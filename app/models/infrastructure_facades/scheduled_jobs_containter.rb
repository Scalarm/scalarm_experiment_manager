# Methods to implement in classes including/subclasses
# - scheduled_jobs: returns array of specific AbstractScheduledJob

module ScheduledJobsContainter
  # @return [Array<Hash>] collection of simulation managers tree nodes
  def sm_nodes(user_id)
    scheduled_jobs(user_id).map &:tree_node
  end
end
