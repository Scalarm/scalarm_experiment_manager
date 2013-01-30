class CreateExperimentQueues < ActiveRecord::Migration
  def self.up
    create_table :experiment_queues do |t|
      t.integer :experiment_id
      t.timestamps
    end
  end

  def self.down
    drop_table :experiment_queues
  end
end
