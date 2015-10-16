module WorkersScaling
  ##
  # Class containing global constants for WorkersScaling module
  class Constants
    ##
    # Queries for categories of workers:
    # Starting - state is :created or :initializing or no simulation is finished
    # Running  - state is :running and at least one simulation is finished
    # Stopping - state is :terminating or simulations_limit is already set
    # Limited  - state is not :error (limited Workers are Workers that count against limits)
    STARTING_WORKERS_QUERY = {'$or' => [
        {state: {'$in' => [:created, :initializing]}},
        {finished_simulations: {'$exists' => false}},
        {finished_simulations: 0}
    ]}
    RUNNING_WORKERS_QUERY  = {'$and' => [
        {state: :running},
        {finished_simulations: {'$gt' => 0}}
    ]}
    STOPPING_WORKERS_QUERY = {'$or' => [
        {state: :terminating},
        {simulations_left: {'$exists' => true}}
    ]}
    LIMITED_WORKERS_QUERY = {state: {'$ne' => :error}}
  end
end
