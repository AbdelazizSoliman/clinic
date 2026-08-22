class StockTransferBatchAllocation < ApplicationRecord
  belongs_to :stock_transfer_item
  belongs_to :source_inventory_batch, class_name: "InventoryBatch"
  belongs_to :destination_inventory_batch, class_name: "InventoryBatch", optional: true
  belongs_to :out_movement, class_name: "InventoryMovement", optional: true
  belongs_to :in_movement, class_name: "InventoryMovement", optional: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :source_inventory_batch_id, uniqueness: { scope: :stock_transfer_item_id }
end
