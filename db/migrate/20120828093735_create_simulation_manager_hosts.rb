class CreateSimulationManagerHosts < ActiveRecord::Migration
  def change
    create_table :simulation_manager_hosts do |t|
      t.string :ip
      t.string :port, :default => "11200"
      t.string :state, :default => "not_running"

      t.timestamps
    end
  end
end
