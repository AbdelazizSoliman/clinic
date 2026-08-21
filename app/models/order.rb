class Order < ApplicationRecord
  belongs_to :user
  belongs_to :cart
  has_many :items, class_name: "OrderItem", dependent: :destroy, inverse_of: :order
  has_one :order_address, dependent: :destroy
  has_one :prescription, dependent: :destroy
  has_many :inventory_reservations, dependent: :destroy
  has_many :events, class_name: "OrderEvent", dependent: :destroy
  has_many :follow_ups, class_name: "OrderFollowUp", dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  belongs_to :cancelled_by, class_name: "User", optional: true
  belongs_to :delivery_zone, optional: true
  belongs_to :delivery_slot, optional: true
  has_one :fulfilment, dependent: :destroy
  has_many :order_promotions, dependent: :destroy
  has_many :promotion_redemptions, dependent: :restrict_with_error
  has_many :return_requests, as: :source, dependent: :restrict_with_error

  enum :status, { pending_prescription: 0, submitted: 1, confirmed: 2, preparing: 3, ready_for_delivery: 4, out_for_delivery: 5, delivered: 6, cancelled: 7, rejected: 8 }, validate: true
  enum :payment_method, { cash_on_delivery: 0, card_placeholder: 1, wallet_placeholder: 2 }, validate: true
  enum :payment_status, { unpaid: 0, pending: 1, paid: 2, failed: 3, refunded: 4 }, validate: true
  enum :delivery_method, { standard: 0, scheduled: 1, pharmacy_pickup: 2 }, validate: true
  enum :cancellation_source, { customer: 0, staff: 1, system: 2 }, prefix: true, validate: { allow_nil: true }

  validates :number, presence: true, uniqueness: true
  validates :currency, inclusion: { in: %w[EGP] }
  validates :subtotal_cents, :discount_cents, :product_discount_cents, :cart_discount_cents,
    :delivery_discount_cents, :delivery_fee_cents, :loyalty_discount_cents, :wallet_paid_cents,
    :cash_on_delivery_due_cents, :total_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :customer_email, :customer_mobile_number, :customer_first_name, :customer_last_name, :submitted_at, presence: true
  validate :total_matches_components
  validate :cancellation_consistency
  validate :delivered_order_is_immutable, on: :update
  before_validation :synchronize_payment_breakdown

  def customer_cancellable? = pending_prescription? || submitted?
  def staff_cancellable? = pending_prescription? || submitted? || confirmed?

  def to_param = number

  private

  def total_matches_components
    expected = subtotal_cents - discount_cents - loyalty_discount_cents + delivery_fee_cents - delivery_discount_cents +
      prescription_adjustment_cents
    return if total_cents == expected

    errors.add(:total_cents, "لا يطابق مكونات الإجمالي")
  end

  validate do
    errors.add(:base, "تفصيل الدفع لا يطابق الإجمالي") unless wallet_paid_cents + cash_on_delivery_due_cents == total_cents
  end

  def cancellation_consistency
    return unless cancelled?

    errors.add(:cancellation_reason, "مطلوب") if cancellation_reason.blank?
    errors.add(:cancelled_at, "مطلوب") if cancelled_at.blank?
    errors.add(:cancellation_source, "مطلوب") if cancellation_source.blank?
  end

  def delivered_order_is_immutable
    return unless status_was == "delivered"
    errors.add(:base, "الطلب المسلم سجل تاريخي غير قابل للتعديل") if changes.except("updated_at").any?
  end

  def synchronize_payment_breakdown
    return unless new_record? || will_save_change_to_total_cents? || will_save_change_to_wallet_paid_cents?
    self.cash_on_delivery_due_cents = total_cents.to_i - wallet_paid_cents.to_i
  end
end
