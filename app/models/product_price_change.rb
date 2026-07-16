class ProductPriceChange < ApplicationRecord
  belongs_to :product
  belongs_to :changed_by, class_name: "User"
  enum :source, { admin: 0, import: 1, promotion: 2, system: 3 }, default: :admin, validate: true
  validates :old_price_cents, :new_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reason, :effective_at, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
