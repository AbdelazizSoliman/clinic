class PromotionRedemption < ApplicationRecord
  belongs_to :promotion
  belongs_to :coupon, optional: true
  belongs_to :user
  belongs_to :order
  enum :status, { redeemed: "redeemed", released: "released" }, validate: true
  validates :promotion_id, uniqueness: { scope: :order_id }
  validates :discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def release!
    with_lock { update!(status: :released, released_at: Time.current) unless released? }
  end
end
