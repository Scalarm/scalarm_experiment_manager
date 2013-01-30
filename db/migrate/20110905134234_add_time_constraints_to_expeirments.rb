class AddTimeConstraintsToExpeirments < ActiveRecord::Migration
  def self.up
    add_column :experiments, :time_constraint_in_sec, :integer
    add_column :experiments, :time_constraint_in_iter, :integer
  end

  def self.down
    remove_column :experiments, :time_constraint_in_sec
    remove_column :experiments, :time_constraint_in_iter
  end
end
