class CreateExperimentProgressBars < ActiveRecord::Migration
  def change
    create_table :experiment_progress_bars do |t|
      t.references :experiment
      t.references :experiment_instance_db

      t.timestamps
    end
    add_index :experiment_progress_bars, :experiment_id
    add_index :experiment_progress_bars, :experiment_instance_db_id
  end
end
