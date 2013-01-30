class ChangeDataTypeForExperimentInstanceCreatedAtAndUpdatedAt < ActiveRecord::Migration
  def self.up
    change_table :experiment_instances do |t|
      t.change :created_at, :timestamp
      t.change :updated_at, :timestamp
    end
  end

  def self.down
    change_table :experiment_instances do |t|
      t.change :created_at, :datetime
      t.change :updated_at, :datetime
    end
  end
end
