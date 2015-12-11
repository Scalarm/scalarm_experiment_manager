module WorkersScaling
  ##
  # Module containing global queries for WorkersScaling module
  module Query
    # Section with workers queries
    module Workers
      ##
      # Initializing - state is :created or :initializing
      INITIALIZING = {state: {'$in' => [:created, :initializing]}}

      ##
      # Starting - state is :running and no simulation is finished
      RUNNING_WITHOUT_FINISHED_SIMULATIONS = {'$and' => [
          {state: :running},
          {'$or' => [
              {finished_simulations: {'$exists' => false}},
              {finished_simulations: 0}
          ]}
      ]}

      ##
      # Running - state is :running and at least one simulation is finished
      RUNNING_WITH_FINISHED_SIMULATIONS  = {'$and' => [
          {state: :running},
          {finished_simulations: {'$gt' => 0}}
      ]}

      ##
      # Stopping - state is :terminating or state is not :error and simulations_limit is already set
      STOPPING = {'$or' => [
          {state: :terminating},
          {'and' => [
              {state: {'$ne' => :error}},
              {simulations_left: {'$exists' => true}}
          ]}
      ]}

      ##
      # Not error - state is not :error (limited Workers are Workers that count against limits)
      NOT_ERROR = {state: {'$ne' => :error}}

      ##
      # Error - state is :error
      ERROR = {state: {'$eq' => :error}}
    end
  end
end
