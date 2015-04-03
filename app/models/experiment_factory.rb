class ExperimentFactory
  DEFAULT_REPLICATION_LEVEL = 1
  DEFAULT_TIME_CONSTRAINT_IN_SECS = 3600
  DEFAULT_SCHEDULING_POLICY = 'monte_carlo'
  DEFAULT_PARAMETER_CONSTRAINTS = {}

  def self.create_experiment(user_id, simulation, params={})
    _create_record(Experiment, user_id, simulation, params)
  end

  def self.create_custom_points_experiment(user_id, simulation, params={})
    experiment = _create_record(CustomPointsExperiment, user_id, simulation, params)
    experiment.init_empty(simulation)

    experiment
  end

  def self.create_supervised_experiment(user_id, simulation, params={})
     _create_record(SupervisedExperiment, user_id, simulation, params)
  end

  private

  def self._create_record(record_class, user_id, simulation, params)
    record_class.new(
        {
             is_running: true,
             simulation_id: simulation.id,
             user_id: user_id,
             replication_level: params[:replication_level] || DEFAULT_REPLICATION_LEVEL,
             time_constraint_in_sec: params[:time_constraint_in_sec] || DEFAULT_TIME_CONSTRAINT_IN_SECS,
             start_at: Time.now,
             scheduling_policy: params[:scheduling_policy] || DEFAULT_SCHEDULING_POLICY,
             name: params[:name] || simulation.name,
             description: params[:description] || simulation.description,
             parameter_constraints: params[:parameter_constraints] || DEFAULT_PARAMETER_CONSTRAINTS
        }
    )
  end
end