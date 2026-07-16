class Order < ApplicationRecord
  belongs_to :user
  belongs_to :cart
  has_many :items, class_name: "OrderItem", dependent: :destroy, inverse_of: :order
  has_one :order_address, dependent: :destroy
  has_one :prescription, dependent: :destroy
  has_many :inventory_reservations, dependent: :destroy

  enum :status, { pending_prescription: 0, submitted: 1, confirmed: 2, preparing: 3, ready_for_delivery: 4, out_for_delivery: 5, delivered: 6, cancelled: 7, rejected: 8 }, validate: true
  enum :payment_method, { cash_on_delivery: 0, card_placeholder: 1, wallet_placeholder: 2 }, validate: true
  enum :payment_status, { unpaid: 0, pending: 1, paid: 2, failed: 3, refunded: 4 }, validate: true
  enum :delivery_method, { standard: 0, scheduled: 1, pharmacy_pickup: 2 }, validate: true

  validates :number, presence: true, uniqueness: true
  validates :currency, inclusion: { in: %w[EGP] }
  validates :subtotal_cents, :discount_cents, :delivery_fee_cents, :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :customer_email, :customer_mobile_number, :customer_first_name, :customer_last_name, :submitted_at, presence: true
  validate :total_matches_components

  def to_param = number

  private

  def total_matches_components
    return if total_cents == subtotal_cents - discount_cents + delivery_fee_cents

    errors.add(:total_cents, "لا يطابق مكونات الإجمالي")
  end
end
