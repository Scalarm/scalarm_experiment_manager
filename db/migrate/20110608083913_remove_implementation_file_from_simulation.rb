class RemoveImplementationFileFromSimulation < ActiveRecord::Migration
  def self.up
    remove_column :simulations, :implementation_file
  end

  def self.down
    add_column :simulations, :implementation_file, :string
  end
end
