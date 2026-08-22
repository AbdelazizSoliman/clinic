class PurchaseReceipt < ApplicationRecord
  after_create_commit { Webhooks::Publish.call("purchase_order.received", { purchase_receipt_id: id, purchase_order_id:, branch_id: }) }
  belongs_to :purchase_order
  belongs_to :branch, default: -> { purchase_order&.branch || Current.branch || Branch.default_branch }
  belongs_to :received_by, class_name: "User"
  has_many :items, class_name: "PurchaseReceiptItem", dependent: :restrict_with_error
  has_many :inventory_batches, dependent: :restrict_with_error

  validates :reference, :idempotency_key, presence: true, uniqueness: true
  validates :received_at, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
