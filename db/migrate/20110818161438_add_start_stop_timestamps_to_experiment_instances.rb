class AddStartStopTimestampsToExperimentInstances < ActiveRecord::Migration
  def self.up
    add_column :experiment_instances, :done_at, :timestamp
  end

  def self.down
    remove_column :experiment_instances, :done_at
  end
end
