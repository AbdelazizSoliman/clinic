class OrderItem < ApplicationRecord
  belongs_to :order, inverse_of: :items
  belongs_to :product, optional: true
  has_many :inventory_reservations, dependent: :destroy
  has_one :prescription_review_item, as: :reviewable_item, dependent: :restrict_with_error

  validates :product_name, :product_slug, :brand_name, :category_name, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, :discount_cents, :line_total_cents, :original_unit_price_cents,
    :final_unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :line_total_matches

  def inventory_reservation = inventory_reservations.order(id: :desc).first

  private

  def line_total_matches
    expected = (final_unit_price_cents || unit_price_cents) * quantity
    errors.add(:line_total_cents, "غير صحيح") unless line_total_cents == expected
  end
end
