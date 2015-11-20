module WorkersScaling
  class ExperimentStatisticsFactory
    @cache = ActiveSupport::Cache::MemoryStore.new expires_in: 10.minutes

    ##
    # Creates new ExperimentStatistics with read-only ExperimentResourcesInterface
    # or uses existing from cache
    # * experiment
    # * user_id
    def self.create_statistics(experiment, user_id)
      @cache.fetch(experiment.id.to_s) do
        ExperimentStatistics.new(
            experiment,
            ExperimentResourcesInterface.new(experiment, user_id, [])
        )
      end
    end
  end
end