require 'singleton'
require 'infrastructure_facades/cluster_record'
require 'infrastructure_facades/scheduler_factory'
require 'infrastructure_facades/cluster_facade'

class ClusterFacadeFactory
  include Singleton

  def provider_names
    ClusterRecord.all.map { |record| "cluster_#{record.id}" }
  end

  def get_facade_for(cluster_id)
    cluster_record_id = cluster_id.split('cluster_').last

    cluster_record = ClusterRecord.where(id: cluster_record_id).first
    return nil if cluster_record.nil?

    scheduler = SchedulerFactory.instance.get_scheduler(cluster_record.scheduler)
    return nil if scheduler.nil?

    ClusterFacade.new(cluster_record, scheduler)
  end
end
