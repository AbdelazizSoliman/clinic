class CompleteTransferLifecycle < ActiveRecord::Migration[8.1]
  def change
    add_reference :stock_transfers, :cancelled_by, foreign_key: { to_table: :users }
    add_column :stock_transfers, :cancelled_at, :datetime
    add_column :stock_transfers, :cancellation_reason, :text
  end
end
