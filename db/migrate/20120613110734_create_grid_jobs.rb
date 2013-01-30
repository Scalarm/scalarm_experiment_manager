class CreateGridJobs < ActiveRecord::Migration
  def change
    create_table :grid_jobs do |t|
      t.integer :time_limit
      t.integer :simulation_limit
      t.references :user

      t.timestamps
    end
    add_index :grid_jobs, :user_id
  end
end
