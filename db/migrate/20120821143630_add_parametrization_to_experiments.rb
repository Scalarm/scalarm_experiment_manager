class AddParametrizationToExperiments < ActiveRecord::Migration
  def change
    add_column :experiments, :parametrization, :string

  end
end
