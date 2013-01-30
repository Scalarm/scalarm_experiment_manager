class AddUserIdToCloudMachine < ActiveRecord::Migration
  def change
    add_column :cloud_machines, :user_id, :integer
  end
end
