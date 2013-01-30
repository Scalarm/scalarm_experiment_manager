class AddRunIndexToExperimentInstances < ActiveRecord::Migration
  def self.up
    add_column :experiment_instances, :run_index, :integer
  end

  def self.down
    remove_column :experiment_instances, :run_index
  end
end
