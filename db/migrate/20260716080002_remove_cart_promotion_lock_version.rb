class RemoveCartPromotionLockVersion < ActiveRecord::Migration[7.2]
  def change
    remove_column :carts, :lock_version, :integer, default: 0, null: false
  end
end
