class Cart < ApplicationRecord
  belongs_to :user, optional: true
  has_many :items, class_name: "CartItem", dependent: :destroy, inverse_of: :cart
  has_one :order, dependent: :restrict_with_error

  enum :status, { active: 0, merged: 1, abandoned: 2, converting: 3, completed: 4 }, default: :active, validate: true

  validates :currency, presence: true, inclusion: { in: %w[EGP] }
  validates :guest_token, uniqueness: true, allow_nil: true
  validate :exactly_one_owner

  def ensure_checkout_submission_token!
    return checkout_submission_token if checkout_submission_token.present?

    update!(checkout_submission_token: SecureRandom.urlsafe_base64(32))
    checkout_submission_token
  rescue ActiveRecord::RecordNotUnique
    reload
    retry
  end

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
