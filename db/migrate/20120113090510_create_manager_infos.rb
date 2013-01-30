class CreateManagerInfos < ActiveRecord::Migration
  def self.up
    create_table :manager_infos do |t|
      t.string :address

      t.timestamps
    end
  end

  def self.down
    drop_table :manager_infos
  end
end
