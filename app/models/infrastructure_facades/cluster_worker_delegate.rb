require_relative 'cluster_onsite_worker_delegate'
require_relative 'cluster_remote_worker_delegate'

class ClusterWorkerDelegate

  def install(record)
    # blank on purpose
  end

  def self.create_delegate(sm_record, cluster_facade)
    if sm_record.onsite_monitoring
      ClusterOnsiteWorkerDelegate.new(cluster_facade.scheduler)
    else
      delegate = ClusterRemoteWorkerDelegate.new(cluster_facade.scheduler)
      delegate.cluster_facade = cluster_facade
      delegate
    end
  end

end
