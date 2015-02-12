class SupervisedExperiment < CustomPointsExperiment

  def init_empty(simulation)
    super simulation
    self.supervised = true
    self.completed = false
    self.result = {}
  end

  def set_result!(result)
    self.result = result
  end

  def mark_as_complete!
    self.completed = true
  end

  def completed?
    self.completed
  end

end