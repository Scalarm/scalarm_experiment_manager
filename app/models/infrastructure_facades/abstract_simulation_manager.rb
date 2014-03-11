# Interface methods:
# - name: name of resource (eg. PLGrid Job ID, VM ID)
# - monitor: checks SM state and takes necessary actions
# - stop: stops and terminates SM with its computational resources (e.g. terminates VM)
# - status: returns status TODO

class AbstractSimulationManager
  attr_reader :record

  def initialize(record)
    @record = record
  end

  def to_hash
    {
        name: name,
        type: 'sm-node'
    }
  end

  def experiment
    @experiment ||= Experiment.find_by_id(record.experiment_id)
  end

  def experiment_end?
    experiment.nil? or
        (experiment.is_running == false) or
        (experiment.experiment_size == experiment.get_statistics[2])
  end
end