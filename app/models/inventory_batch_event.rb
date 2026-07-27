class InventoryBatchEvent < ApplicationRecord
  TYPES = %w[created quarantined quarantine_released adjusted].freeze

  belongs_to :inventory_batch
  belongs_to :actor, class_name: "User", optional: true
  validates :event_type, inclusion: { in: TYPES }
  validates :reason, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
