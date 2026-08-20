class ProductActiveIngredient < ApplicationRecord
  belongs_to :product
  belongs_to :active_ingredient

  scope :active, -> { where(active: true) }

  validates :active_ingredient_id, uniqueness: { scope: :product_id }
  validates :strength, :unit, length: { maximum: 40 }, allow_blank: true
  validates :active, inclusion: { in: [ true, false ] }

  def label
    [ active_ingredient.name, [ strength, unit ].compact_blank.join(" ").presence ].compact.join(" · ")
  end
end
