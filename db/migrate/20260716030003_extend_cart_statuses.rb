class ExtendCartStatuses < ActiveRecord::Migration[7.2]
  def change
    remove_check_constraint :carts, name: "carts_status_valid"
    add_check_constraint :carts, "status IN (0,1,2,3,4)", name: "carts_status_valid"
  end
end
