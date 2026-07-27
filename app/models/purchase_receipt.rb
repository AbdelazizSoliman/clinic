class PurchaseReceipt < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :received_by, class_name: "User"
  has_many :items, class_name: "PurchaseReceiptItem", dependent: :restrict_with_error

  validates :reference, :idempotency_key, presence: true, uniqueness: true
  validates :received_at, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
