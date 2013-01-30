class AddNodeInfoToVirtualMachines < ActiveRecord::Migration
  def self.up
    add_column :virtual_machines, :cpus, :integer, :default => 0
    add_column :virtual_machines, :memory, :float, :default => 0.0
  end

  def self.down
    remove_column :virtual_machines, :memory
    remove_column :virtual_machines, :cpus
  end
end
