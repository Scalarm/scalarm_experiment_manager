class AddRandomValueToExperimentInstances < ActiveRecord::Migration
  def self.up
      add_column :experiment_instances, :random_value, :float
  end

  def self.down
      add_column :experiment_instances, :random_value
  end
end
