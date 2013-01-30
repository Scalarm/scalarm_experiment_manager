class CreatePhysicalMachines < ActiveRecord::Migration
  def self.up
    create_table :physical_machines do |t|
      t.string :ip
      t.string :username
      t.string :state

      t.timestamps
    end
  end

  def self.down
    drop_table :physical_machines
  end
end
