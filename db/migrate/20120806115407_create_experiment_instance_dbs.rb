class CreateExperimentInstanceDbs < ActiveRecord::Migration
  def change
    create_table :experiment_instance_dbs do |t|
      t.string :ip
      t.integer :port

      t.timestamps
    end
  end
end
