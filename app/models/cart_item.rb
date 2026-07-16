class CartItem < ApplicationRecord
  MAX_QUANTITY = 10

  belongs_to :cart, inverse_of: :items
  belongs_to :product

  validates :product_id, uniqueness: { scope: :cart_id }
  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_QUANTITY }

  def subtotal_cents
    (product.price * 100).round * quantity
  end
end
