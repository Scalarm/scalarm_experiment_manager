module StatisticsAPI

  def get_simulations_ids
    # TODO
  end

  def get_simulation(id, params = {})
    # TODO
  end

  def get_simulations(ids, params = {})
    ids.map { |id| get_simulation id, params}.to_a # TODO
  end

  def get_simulation_execution_statistics(id, params = {})
    # TODO
  end

  def get_simulations_execution_statistics(ids, params = {})
    ids.map { |id| get_simulation_execution_statistics id, params}.to_a # TODO
  end

end
