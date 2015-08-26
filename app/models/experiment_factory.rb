class ExperimentFactory
  DEFAULT_REPLICATION_LEVEL = 1
  DEFAULT_TIME_CONSTRAINT_IN_SECS = 3600
  DEFAULT_SCHEDULING_POLICY = 'monte_carlo'
  DEFAULT_PARAMETER_CONSTRAINTS = {}

  def self.create_experiment(user_id, simulation, params={})
    r = _create_record(Experiment, user_id, simulation, params)
    r.share_with_anonymous
    r
  end

  def self.create_custom_points_experiment(user_id, simulation, params={})
    experiment = _create_record(CustomPointsExperiment, user_id, simulation, params)
    experiment.init_empty(simulation)

    experiment
  end

  def self.create_supervised_experiment(user_id, simulation, params={})
    experiment = _create_record(SupervisedExperiment, user_id, simulation, params)
    experiment.init_empty(simulation)

    experiment
  end

  private

  def self._create_record(record_class, user_id, simulation, params)
    params = Hash[params.collect {|k, v| [k.to_sym, v]}]

    replication_level = params.delete(:replication_level) || DEFAULT_REPLICATION_LEVEL
    time_constraint_in_sec = params.delete(:time_constraint_in_sec) || DEFAULT_TIME_CONSTRAINT_IN_SECS
    scheduling_policy = params.delete(:scheduling_policy) || DEFAULT_SCHEDULING_POLICY
    name = params.delete(:experiment_name) || simulation.name
    description = params.delete(:experiment_description) || simulation.description
    parameters_constraints = params.delete(:parameters_constraints) || DEFAULT_PARAMETER_CONSTRAINTS

    record_class.new(
        params.merge({
             is_running: true,
             simulation_id: simulation.id,
             user_id: user_id,
             replication_level: replication_level,
             time_constraint_in_sec: time_constraint_in_sec,
             start_at: Time.now,
             scheduling_policy: scheduling_policy,
             name: name,
             description: description,
             parameters_constraints: parameters_constraints
        })
    )
  end
end