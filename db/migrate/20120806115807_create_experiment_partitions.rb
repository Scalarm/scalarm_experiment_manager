class CreateExperimentPartitions < ActiveRecord::Migration
  def change
    create_table :experiment_partitions do |t|
      t.references :experiment
      t.references :experiment_instance_db
      t.integer :start_id
      t.integer :end_id

      t.timestamps
    end
  end
end
