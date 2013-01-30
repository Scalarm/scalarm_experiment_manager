class LinkingExperimentsWithSimulations < ActiveRecord::Migration
  def self.up
    change_table :simulations do |t|
      t.references :experiment
    end

    change_table :experiments do |t|
      t.references :simulation
    end
  end

  def self.down
    remove_column :simulations, :experiments_id
    remove_column :experiments, :simulations_id
  end
end
