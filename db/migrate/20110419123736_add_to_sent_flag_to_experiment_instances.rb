class AddToSentFlagToExperimentInstances < ActiveRecord::Migration
  def self.up
    add_column :experiment_instances, :to_sent, :boolean, :default => 1
  end

  def self.down
    remove_column :experiment_instances, :to_sent
  end
end
