class ReturnItem < ApplicationRecord
  belongs_to :return_request, inverse_of: :items
  belongs_to :source_item, polymorphic: true
  belongs_to :original_product, class_name: "Product", optional: true
  belongs_to :dispensed_product, class_name: "Product", optional: true
  belongs_to :inspected_by, class_name: "User", optional: true
  has_many :batch_allocations, class_name: "ReturnItemBatchAllocation", dependent: :restrict_with_error

  enum :reason, { customer_changed_mind: 0, damaged: 1, wrong_item: 2, dispensing_error: 3,
    quality_issue: 4, expired: 5, other: 6 }, validate: true
  enum :condition, { unopened: 0, opened: 1, damaged: 2, expired: 3, compromised: 4, unknown: 5 },
    default: :unknown, validate: true, prefix: true
  enum :disposition, { restock: 0, quarantine: 1, write_off: 2, destroy_pending: 3 },
    validate: { allow_nil: true }, prefix: true

  validates :requested_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :approved_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: :requested_quantity }
  validates :received_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: :approved_quantity }
  validates :unit_price_cents, :allocated_discount_cents, :tax_cents, :refundable_amount_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reason_notes, presence: true, if: -> { other? }
  validate :source_matches_return

  def product_name = source_item.product_name

  private

  def source_matches_return
    expected = return_request&.source_type == "Order" ? "OrderItem" : "PosSaleItem"
    errors.add(:source_item, "لا يطابق مصدر المرتجع") unless source_item_type == expected
  end
end
