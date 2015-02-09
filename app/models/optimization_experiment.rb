class OptimizationExperiment < CustomPointsExperiment

  alias_method :super_init_empty, :init_empty

  def init_empty(simulation)
    super_init_empty simulation
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