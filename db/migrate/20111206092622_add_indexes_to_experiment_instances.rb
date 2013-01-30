class AddIndexesToExperimentInstances < ActiveRecord::Migration
  def self.up
      add_index :experiment_instances, :to_sent, :name => "to_sent_idx"
      add_index :experiment_instances, :is_done, :name => "is_done_idx"
      add_index :experiment_instances, :experiment_id, :name => "experiment_id_idx"
      add_index :experiment_instances, :created_at, :name => "created_at_idx"
  end

  def self.down
      remove_index :experiment_instances, :to_sent
      remove_index :experiment_instances, :is_done
      remove_index :experiment_instances, :experiment_id
      remove_index :experiment_instances, :created_at
  end
end
