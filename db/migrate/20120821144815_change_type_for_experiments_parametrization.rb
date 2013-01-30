class ChangeTypeForExperimentsParametrization < ActiveRecord::Migration
  def change
    change_column :experiments, :parametrization, :text
  end
end
