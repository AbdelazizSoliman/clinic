class PurchaseOrderEvent < ApplicationRecord
  TYPES = %w[created updated submitted approved receipt_posted partially_received fully_received cancelled closed].freeze
  belongs_to :purchase_order
  belongs_to :actor, class_name: "User", optional: true
  validates :event_type, inclusion: { in: TYPES }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
