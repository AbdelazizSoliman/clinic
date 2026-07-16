class WishlistItem < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :product_id, uniqueness: { scope: :user_id }
  validate :product_must_be_active, on: :create

  private

  def product_must_be_active
    errors.add(:product, "غير متاح للحفظ") if product && !product.active?
  end
end
