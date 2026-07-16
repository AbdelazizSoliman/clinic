class PromotionCategory < ApplicationRecord
  belongs_to :promotion
  belongs_to :category
  validates :category_id, uniqueness: { scope: :promotion_id }
end
