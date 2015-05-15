module StatisticsAPI

  ##
  # Returns indices of already created SimulationRuns for current Experiment
  def get_simulations_ids
    simulation_runs.all.to_a.map { |sr| sr.index }
  end

  ##
  # Returns SimulationRun
  # * id - index of SimulationRun (not _id)
  # * params - additional parameters
  def get_simulation(id, params = {})
    simulation_runs.where(index: id.to_i).first
  end

  ##
  # Returns SimulationRuns
  # * ids - list od indices of SimulationRuns (not _id)
  # * params - additional parameters
  def get_simulations(ids, params = {})
    ids.map { |id| get_simulation id, params}
  end

  ##
  # Returns execution_statistics for SimulationRun
  # * id - index of SimulationRun (not _id)
  # * params - additional parameters
  def get_simulation_execution_statistics(id, params = {})
    get_simulation(id, params).simulation_statistics
  end

  ##
  # Returns execution_statistics for SimulationRuns
  # * ids - list od indices of SimulationRuns (not _id)
  # * params - additional parameters
  def get_simulations_execution_statistics(ids, params = {})
    get_simulations(ids, params).map { |sr| sr.simulation_statistics }
  end

end
