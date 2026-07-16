class PromotionBrand < ApplicationRecord
  belongs_to :promotion
  belongs_to :brand
  validates :brand_id, uniqueness: { scope: :promotion_id }
end
