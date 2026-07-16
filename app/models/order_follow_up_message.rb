class OrderFollowUpMessage < ApplicationRecord
  belongs_to :order_follow_up
  belongs_to :author, class_name: "User"
  validates :body, :author_role, presence: true
  validates :customer_visible, inclusion: { in: [ true, false ] }
  validate :customer_cannot_be_internal

  before_update { throw :abort }
  before_destroy { throw :abort }

  private

  def customer_cannot_be_internal
    errors.add(:customer_visible, "رسائل العميل يجب أن تكون ظاهرة") if author&.customer? && !customer_visible?
  end
end
