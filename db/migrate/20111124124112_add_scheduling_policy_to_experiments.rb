class AddSchedulingPolicyToExperiments < ActiveRecord::Migration
    def self.up
      add_column :experiments, :scheduling_policy, :string, :default => 'monte_carlo'
    end

    def self.down
      remove_column :experiments, :scheduling_policy
    end
end
