class CreateCloudMachines < ActiveRecord::Migration
  def change
    create_table :cloud_machines do |t|
      t.string :amazon_id
      t.string :amazon_status

      t.timestamps
    end
  end
end
