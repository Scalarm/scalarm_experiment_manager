class AddExperimentNameAndExperimentFileToExperiments < ActiveRecord::Migration
  def change
    add_column :experiments, :experiment_name, :string

    add_column :experiments, :experiment_file, :string
  end
end
