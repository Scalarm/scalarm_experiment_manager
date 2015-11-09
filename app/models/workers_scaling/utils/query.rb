module WorkersScaling
  ##
  # Module containing global Workers queries for WorkersScaling module
  module Query
    ##
    # Queries for categories of workers:
    # Initializing - state is :created or :initializing
    # Starting     - state is :running and no simulation is finished
    # Running      - state is :running and at least one simulation is finished
    # Stopping     - state is :terminating or state is not :error and simulations_limit is already set
    # Limited      - state is not :error (limited Workers are Workers that count against limits)
    INITIALIZING_WORKERS = {state: {'$in' => [:created, :initializing]}}
    STARTING_WORKERS = {'$and' => [
      {state: :running},
      {'$or' => [
          {finished_simulations: {'$exists' => false}},
          {finished_simulations: 0}
      ]}
    ]}
    RUNNING_WORKERS  = {'$and' => [
      {state: :running},
      {finished_simulations: {'$gt' => 0}}
    ]}
    STOPPING_WORKERS = {'$or' => [
      {state: :terminating},
      {'and' => [
        {state: {'$ne' => :error}},
        {simulations_left: {'$exists' => true}}
      ]}
    ]}
    LIMITED_WORKERS = {state: {'$ne' => :error}}
  end
end
