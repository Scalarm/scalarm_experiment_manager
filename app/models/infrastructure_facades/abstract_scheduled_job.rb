# Interface methods:
# - name: name of resource (eg. PLGrid Job ID, VM ID)
# - monitor: checks SM state and takes necessary actions
# - stop: stops and terminates SM with its computational resources (e.g. terminates VM)
# - status: returns status TODO

class AbstractScheduledJob
  attr_reader :record

  def initialize(record)
    @record = record
  end

  def tree_node
    {
        name: name
    }
  end
end