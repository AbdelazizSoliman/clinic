class InventoryMovement < ApplicationRecord
  after_create_commit { Webhooks::Publish.call("inventory.changed", { movement_id: id, product_id:, branch_id:, quantity_delta: }) }
  belongs_to :product
  belongs_to :branch, default: -> { inventory_batch&.branch || Current.branch || Branch.default_branch }
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :reference, polymorphic: true, optional: true
  belongs_to :inventory_batch, optional: true
  enum :movement_type, { opening_balance: 0, manual_increase: 1, manual_decrease: 2, correction: 3,
    reservation_consumed: 4, return_to_stock: 5, damaged: 6, expired: 7, system_adjustment: 8,
    purchase_received: 9, batch_loss: 10, supplier_replacement: 11, pos_sale: 12,
    return_restock: 13, return_quarantine: 14, return_write_off: 15, return_destroy_pending: 16,
    branch_transfer_out: 17, branch_transfer_in: 18 }, validate: true
  validates :quantity_delta, numericality: { only_integer: true }
  validate { errors.add(:quantity_delta, "يجب ألا يساوي صفراً") if quantity_delta.zero? && !return_write_off? && !return_destroy_pending? }
  validates :quantity_before, :quantity_after, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reason, presence: true
  validates :idempotency_key, uniqueness: true, allow_nil: true
  validate { errors.add(:quantity_after, "لا يطابق الحركة") unless quantity_after == quantity_before + quantity_delta }
  validate :batch_quantities_reconcile
  before_update { throw :abort }
  before_destroy { throw :abort }

  private

  def batch_quantities_reconcile
    return unless inventory_batch
    unless batch_quantity_before && batch_quantity_after &&
        batch_quantity_after == batch_quantity_before + quantity_delta
      errors.add(:batch_quantity_after, "لا يطابق حركة التشغيلة")
    end
    errors.add(:product, "لا يطابق التشغيلة") unless product_id == inventory_batch.product_id
    errors.add(:branch, "لا يطابق فرع التشغيلة") unless branch_id == inventory_batch.branch_id
  end
end
