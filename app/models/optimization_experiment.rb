class OptimizationExperiment < CustomPointsExperiment

  def init_empty(simulation)
    super simulation
    self.finished = false
    self.result = {}
  end

  def add_result!(result)
    self.result = result
  end

  def finish!
    self.finished = true
  end

end