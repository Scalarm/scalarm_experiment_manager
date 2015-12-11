module WorkersScaling
  class ExperimentMetricsFactory

    ##
    # Creates new ExperimentMetrics with read-only ExperimentResourcesInterface
    # @param experiment [Experiment]
    # @param user_id [BSON::ObjectId, String]
    # @return [ExperimentMetrics]
    def self.create_metrics(experiment, user_id)
      ExperimentMetrics.new(
          experiment,
          ExperimentResourcesInterface.new(experiment, user_id, [])
      )
    end
  end
end