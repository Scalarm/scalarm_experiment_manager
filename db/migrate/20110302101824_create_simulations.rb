class CreateSimulations < ActiveRecord::Migration
  def self.up
    create_table :simulations do |t|
      t.string :name
      t.text :description
      t.string :implementation_file
      t.string :scenario_file
      t.string :other_file

      t.timestamps
    end
  end

  def self.down
    drop_table :simulations
  end
end
