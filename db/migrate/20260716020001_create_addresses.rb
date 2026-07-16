class CreateAddresses < ActiveRecord::Migration[7.2]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :label, null: false, limit: 50
      t.string :recipient_name, null: false, limit: 120
      t.string :mobile_number, null: false, limit: 20
      t.string :governorate, null: false, limit: 80
      t.string :city, null: false, limit: 100
      t.string :district, limit: 100
      t.string :street, null: false, limit: 200
      t.string :building_number, null: false, limit: 30
      t.string :floor, limit: 30
      t.string :apartment, limit: 30
      t.string :landmark, limit: 200
      t.text :delivery_notes
      t.string :postal_code, limit: 20
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.boolean :default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :addresses, :user_id, unique: true, where: "active = TRUE AND \"default\" = TRUE", name: "index_addresses_one_active_default"
    add_check_constraint :addresses, "latitude IS NULL OR latitude BETWEEN -90 AND 90", name: "addresses_latitude_range"
    add_check_constraint :addresses, "longitude IS NULL OR longitude BETWEEN -180 AND 180", name: "addresses_longitude_range"
  end
end
