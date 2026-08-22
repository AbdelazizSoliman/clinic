class StockTransferItem < ApplicationRecord
  belongs_to :stock_transfer
  belongs_to :product
  has_many :batch_allocations, class_name: "StockTransferBatchAllocation", dependent: :restrict_with_error
  validates :product_id, uniqueness: { scope: :stock_transfer_id }
  validates :requested_quantity, numericality: { only_integer: true, greater_than: 0 }
end
