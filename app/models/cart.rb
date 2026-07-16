class Cart < ApplicationRecord
  belongs_to :user, optional: true
  has_many :items, class_name: "CartItem", dependent: :destroy, inverse_of: :cart

  enum :status, { active: 0, merged: 1, abandoned: 2 }, default: :active, validate: true

  validates :currency, presence: true, inclusion: { in: %w[EGP] }
  validates :guest_token, uniqueness: true, allow_nil: true
  validate :exactly_one_owner

  def total_quantity = items.sum(:quantity)

  def valid_items
    items.includes(product: :brand).select { |item| item.product.active? && item.product.available? }
  end

  def subtotal_cents
    valid_items.sum(&:subtotal_cents)
  end

  def requires_prescription?
    valid_items.any? { |item| item.product.requires_prescription? }
  end

  private

  def exactly_one_owner
    errors.add(:base, "يجب أن ترتبط السلة بمستخدم أو جلسة ضيف واحدة") if user.present? == guest_token.present?
  end
end
