class AddExperimentsToUsers < ActiveRecord::Migration
  def change
    add_column :experiments, :user_id, :integer
  end
end
