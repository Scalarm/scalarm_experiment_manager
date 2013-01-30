class CreateExperimentInstances < ActiveRecord::Migration
  def self.up
    create_table :experiment_instances do |t|
      t.boolean :is_done
      t.references :experiment
      t.text :arguments
      t.text :values

      t.timestamps
    end
  end

  def self.down
    drop_table :experiment_instances
  end
end
