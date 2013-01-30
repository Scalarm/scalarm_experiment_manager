class CreateExperiments < ActiveRecord::Migration
  def self.up
    create_table :experiments do |t|
      t.boolean :is_running
      t.timestamp :start_at
      t.timestamp :end_at
      t.text :arguments

      t.timestamps
    end
  end

  def self.down
    drop_table :experiments
  end
end
