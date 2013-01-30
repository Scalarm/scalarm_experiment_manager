class CreateManagerFailureInfos < ActiveRecord::Migration
  def self.up
    create_table :manager_failure_infos do |t|
      t.text :info
      t.date :when
      t.references :manager

      t.timestamps
    end
  end

  def self.down
    drop_table :manager_failure_infos
  end
end
