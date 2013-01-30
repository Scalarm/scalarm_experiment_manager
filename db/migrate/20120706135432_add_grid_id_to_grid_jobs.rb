class AddGridIdToGridJobs < ActiveRecord::Migration
  def change
    add_column :grid_jobs, :grid_id, :string
  end
end
