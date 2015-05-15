module StatisticsAPI

  ##
  # Returns ids of already created SimulationRuns for current Experiment
  def get_simulation_runs_ids
    simulation_runs.where({}, :fields => ['_id']).all.to_a.map { |sr| sr._id }
  end

  ##
  # Returns SimulationRun
  # * id - id of SimulationRun
  # * params - additional parameters
  def get_simulation_run(id, params = {})
    simulation_runs.where({_id: id}, params).first
  end

  ##
  # Returns SimulationRuns
  # * ids - list od ids of SimulationRuns
  # * params - additional parameters
  def get_simulation_runs(ids, params = {})
    ids.map { |id| get_simulation_run id, params}
  end

end
