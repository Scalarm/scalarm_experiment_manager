class AddRunCounterToExperiments < ActiveRecord::Migration
  def self.up
    add_column :experiments, :run_counter, :integer
  end

  def self.down
    remove_column :experiments, :run_counter
  end
end
