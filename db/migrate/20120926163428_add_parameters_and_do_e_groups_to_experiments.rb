class AddParametersAndDoEGroupsToExperiments < ActiveRecord::Migration
  def change
    add_column :experiments, :parameters, :string
    add_column :experiments, :doe_groups, :string
  end
end
