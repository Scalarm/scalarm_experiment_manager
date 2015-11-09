module WorkersScaling
  ##
  # Module containing global Workers queries for WorkersScaling module
  module Query
    ##
    # Initializing - state is :created or :initializing
    INITIALIZING_WORKERS = {state: {'$in' => [:created, :initializing]}}

    ##
    # Starting - state is :running and no simulation is finished
    STARTING_WORKERS = {'$and' => [
      {state: :running},
      {'$or' => [
          {finished_simulations: {'$exists' => false}},
          {finished_simulations: 0}
      ]}
    ]}

    ##
    # Running - state is :running and at least one simulation is finished
    RUNNING_WORKERS  = {'$and' => [
      {state: :running},
      {finished_simulations: {'$gt' => 0}}
    ]}

    ##
    # Stopping - state is :terminating or state is not :error and simulations_limit is already set
    STOPPING_WORKERS = {'$or' => [
      {state: :terminating},
      {'and' => [
        {state: {'$ne' => :error}},
        {simulations_left: {'$exists' => true}}
      ]}
    ]}

    ##
    # Limited - state is not :error (limited Workers are Workers that count against limits)
    LIMITED_WORKERS = {state: {'$ne' => :error}}
  end
end
