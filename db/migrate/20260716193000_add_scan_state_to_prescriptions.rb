class AddScanStateToPrescriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :prescriptions, :scan_status, :integer, null: false, default: 1
    add_column :prescriptions, :scan_failure_class, :string
    add_column :prescriptions, :scanned_at, :datetime
    add_index :prescriptions, %i[scan_status created_at]
  end
end
