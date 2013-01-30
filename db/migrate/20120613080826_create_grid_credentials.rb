class CreateGridCredentials < ActiveRecord::Migration
  def change
    create_table :grid_credentials do |t|
      t.string :login
      t.string :password
      t.string :host
      t.references :user

      t.timestamps
    end
    add_index :grid_credentials, :user_id
  end
end
