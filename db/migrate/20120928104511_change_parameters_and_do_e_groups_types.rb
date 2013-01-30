class ChangeParametersAndDoEGroupsTypes < ActiveRecord::Migration
  def change
    change_column :experiments, :parameters, :text
    change_column :experiments, :doe_groups, :text
  end
end
