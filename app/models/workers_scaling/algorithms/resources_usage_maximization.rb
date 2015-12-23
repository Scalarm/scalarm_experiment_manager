module WorkersScaling

  ##
  # Resources usage maximization algorithm will use all available
  # computational resources through entire experiment
  class ResourcesUsageMaximization < Algorithm

    def self.algorithm_name
      'Resources usage maximization'
    end

    def self.description
      'Method will use all available computational power through entire experiment.'
    end

    ##
    # Schedules maximum number of workers to all available infrastructures
    def schedule_workers
      log(:debug, 'Schedule maximum number of workers to all available resource configurations')
      @resources_interface.get_available_resource_configurations.each do |configuration|
        log(:debug, "#{configuration.inspect}")
        @resources_interface.schedule_workers(Float::INFINITY, configuration)
      end
    end

    ##
    # Description at #schedule_workers
    def initial_deployment
      schedule_workers
    end

    ##
    # Description at #schedule_workers
    def execute_algorithm_step
      schedule_workers
    end

  end

end
