class AddResultToExperimentInstances < ActiveRecord::Migration
  def self.up
    add_column :experiment_instances, :result, :text
  end

  def self.down
    remove_column :experiment_instances, :result
  end
end
