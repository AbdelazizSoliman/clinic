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

  enum :status, { pending_prescription: 0, submitted: 1, confirmed: 2, preparing: 3, ready_for_delivery: 4, out_for_delivery: 5, delivered: 6, cancelled: 7, rejected: 8 }, validate: true
  enum :payment_method, { cash_on_delivery: 0, card_placeholder: 1, wallet_placeholder: 2 }, validate: true
  enum :payment_status, { unpaid: 0, pending: 1, paid: 2, failed: 3, refunded: 4 }, validate: true
  enum :delivery_method, { standard: 0, scheduled: 1, pharmacy_pickup: 2 }, validate: true
  enum :cancellation_source, { customer: 0, staff: 1, system: 2 }, prefix: true, validate: { allow_nil: true }

  validates :number, presence: true, uniqueness: true
  validates :currency, inclusion: { in: %w[EGP] }
  validates :subtotal_cents, :discount_cents, :product_discount_cents, :cart_discount_cents,
    :delivery_discount_cents, :delivery_fee_cents, :total_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :customer_email, :customer_mobile_number, :customer_first_name, :customer_last_name, :submitted_at, presence: true
  validate :total_matches_components
  validate :cancellation_consistency

  def customer_cancellable? = pending_prescription? || submitted?
  def staff_cancellable? = pending_prescription? || submitted? || confirmed?

  def to_param = number

  private

  def total_matches_components
    return if total_cents == subtotal_cents - discount_cents + delivery_fee_cents - delivery_discount_cents

    errors.add(:total_cents, "لا يطابق مكونات الإجمالي")
  end

  def cancellation_consistency
    return unless cancelled?

    errors.add(:cancellation_reason, "مطلوب") if cancellation_reason.blank?
    errors.add(:cancelled_at, "مطلوب") if cancelled_at.blank?
    errors.add(:cancellation_source, "مطلوب") if cancellation_source.blank?
  end
end
