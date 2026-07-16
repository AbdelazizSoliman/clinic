class PromotionProduct < ApplicationRecord
  belongs_to :promotion
  belongs_to :product
  validates :product_id, uniqueness: { scope: :promotion_id }
end
