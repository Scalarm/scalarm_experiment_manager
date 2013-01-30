class CreateVirtualMachines < ActiveRecord::Migration
  def self.up
    create_table :virtual_machines do |t|
      t.string :ip
      t.string :username
      t.string :state
      t.references :physical_machine
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :virtual_machines
  end
end
