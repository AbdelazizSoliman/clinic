class OrderEvent < ApplicationRecord
  TYPES = %w[order_submitted prescription_review_started prescription_approved prescription_partially_approved prescription_rejected order_confirmed preparation_started order_ready out_for_delivery delivered cancelled rejected reservations_released reservations_consumed].freeze

  belongs_to :order
  belongs_to :actor, class_name: "User", optional: true
  validates :event_type, inclusion: { in: TYPES }
  validates :customer_visible, inclusion: { in: [ true, false ] }

  before_update { throw :abort }
  before_destroy { throw :abort }
end
