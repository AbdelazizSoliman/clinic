class DeviseCreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :mobile_number, null: false
      t.integer :role, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_check_constraint :users, "role IN (0, 1)", name: "users_role_valid"
  end
end
