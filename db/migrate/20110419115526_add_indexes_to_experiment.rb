class AddIndexesToExperiment < ActiveRecord::Migration
  def self.up
    add_column :experiments, :instance_index, :integer
  end

  def self.down
    remove_column :experiments, :instance_index
  end
end
