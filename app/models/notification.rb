class Notification < ApplicationRecord
  KINDS = %w[follow_up_requested follow_up_response_received prescription_approved prescription_rejected prescription_partial order_confirmed order_preparing order_ready order_out_for_delivery order_delivered order_cancelled reservation_expiring reservation_expired product_low_stock product_out_of_stock delivery_assigned delivery_scheduled].freeze

  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true
  validates :kind, inclusion: { in: KINDS }
  validates :title, :body, presence: true
  validates :deduplication_key, uniqueness: true, allow_nil: true
  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  def read! = update!(read_at: read_at || Time.current)
end
