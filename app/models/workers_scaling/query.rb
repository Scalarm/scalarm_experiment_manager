module WorkersScaling
  ##
  # Module containing global Workers queries for WorkersScaling module
  module Query
    ##
    # Queries for categories of workers:
    # Starting - state is :created or :initializing or no simulation is finished
    # Running  - state is :running and at least one simulation is finished
    # Stopping - state is :terminating or simulations_limit is already set
    # Limited  - state is not :error (limited Workers are Workers that count against limits)
    STARTING_WORKERS = {'$or' => [
        {state: {'$in' => [:created, :initializing]}},
        {finished_simulations: {'$exists' => false}},
        {finished_simulations: 0}
    ]}
    RUNNING_WORKERS  = {'$and' => [
        {state: :running},
        {finished_simulations: {'$gt' => 0}}
    ]}
    STOPPING_WORKERS = {'$or' => [
        {state: :terminating},
        {simulations_left: {'$exists' => true}}
    ]}
    LIMITED_WORKERS = {state: {'$ne' => :error}}
  end
end
