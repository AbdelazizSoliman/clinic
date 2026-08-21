class PosPayment < ApplicationRecord
  belongs_to :pos_sale

  enum :payment_method, { cash: 0, external_card: 1, wallet: 2 }, validate: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :tendered_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :change_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :tender_is_consistent
  before_update { throw :abort }
  before_destroy { throw :abort }

  private

  def tender_is_consistent
    if cash?
      errors.add(:tendered_cents, "يجب أن يغطي المبلغ") unless tendered_cents.to_i >= amount_cents.to_i
      errors.add(:change_cents, "غير صحيح") unless change_cents == tendered_cents.to_i - amount_cents.to_i
    elsif tendered_cents.present? || change_cents.positive?
      errors.add(:base, "الباقي يخص الدفع النقدي فقط")
    end
  end
end
