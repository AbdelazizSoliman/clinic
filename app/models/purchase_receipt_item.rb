class PurchaseReceiptItem < ApplicationRecord
  belongs_to :purchase_receipt
  belongs_to :purchase_order_item
  belongs_to :inventory_movement

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :purchase_order_item_id, uniqueness: { scope: :purchase_receipt_id }
  validates :inventory_movement_id, uniqueness: true
  validate :line_belongs_to_receipt_order
  validate :movement_matches_receipt_and_product
  before_update { throw :abort }
  before_destroy { throw :abort }

  def self.latest_cost_for(product:, supplier: nil)
    scope = joins(:purchase_receipt, purchase_order_item: :purchase_order)
      .where(purchase_order_items: { product_id: product.id })
    scope = scope.where(purchase_orders: { supplier_id: supplier.id }) if supplier
    scope.order("purchase_receipts.received_at DESC", id: :desc).pick(:unit_cost_cents)
  end

  private

  def line_belongs_to_receipt_order
    return unless purchase_receipt && purchase_order_item
    return if purchase_receipt.purchase_order_id == purchase_order_item.purchase_order_id

    errors.add(:purchase_order_item, "لا ينتمي إلى أمر الشراء الخاص بالإيصال")
  end

  def movement_matches_receipt_and_product
    return unless inventory_movement && purchase_receipt && purchase_order_item
    valid = inventory_movement.purchase_received? &&
      inventory_movement.reference == purchase_receipt &&
      inventory_movement.product_id == purchase_order_item.product_id &&
      inventory_movement.quantity_delta == quantity
    errors.add(:inventory_movement, "لا يطابق بند الاستلام") unless valid
  end
end
