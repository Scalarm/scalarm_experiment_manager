class AddNodeInfoToPhysicalMachines < ActiveRecord::Migration
  def self.up
    add_column :physical_machines, :cpus, :integer, :default => 0
    add_column :physical_machines, :cpu_model, :string, :default => ""
    add_column :physical_machines, :cpu_freq, :string, :default => ""
    add_column :physical_machines, :memory, :float, :default => 0.0
  end

  def self.down
    remove_column :physical_machines, :memory
    remove_column :physical_machines, :cpu_freq
    remove_column :physical_machines, :cpu_model
    remove_column :physical_machines, :cpus
  end
end
