class AddVmCounterToExperiments < ActiveRecord::Migration
  def self.up
    add_column :experiments, :vm_counter, :integer, :default => 0
  end

  def self.down
    remove_column :experiments, :vm_counter
  end
end
