class AddExperimentSizeToExperiments < ActiveRecord::Migration
  def self.up
    add_column :experiments, :experiment_size, :integer
  end

  def self.down
    remove_column :experiments, :experiment_size
  end
end
