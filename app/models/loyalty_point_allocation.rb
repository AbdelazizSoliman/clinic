class LoyaltyPointAllocation < ApplicationRecord
  belongs_to :earn_entry, class_name: "LoyaltyLedgerEntry"
  belongs_to :debit_entry, class_name: "LoyaltyLedgerEntry"
  validates :earn_entry_id, uniqueness: { scope: :debit_entry_id }
  validates :points, numericality: { only_integer: true, greater_than: 0 }
  validate { errors.add(:earn_entry, "يجب أن يكون قيداً دائناً") unless earn_entry&.credit? }
  validate { errors.add(:debit_entry, "يجب أن يكون قيد خصم") unless debit_entry && !debit_entry.credit? }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
