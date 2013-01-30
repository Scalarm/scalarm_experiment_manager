class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :username
      t.string :password_salt
      t.string :password_hash

      t.timestamps
    end

    #eusas_user = User.new(:username => "eusas")
    #eusas_user.password="change.ME"
    #eusas_user.save
  end
end
