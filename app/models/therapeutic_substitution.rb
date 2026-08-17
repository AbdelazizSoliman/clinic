class TherapeuticSubstitution < ApplicationRecord
  belongs_to :prescription_review_item
  belongs_to :original_product, class_name: "Product"
  belongs_to :substitute_product, class_name: "Product"
  belongs_to :pharmacist, class_name: "User"

  validates :prescription_review_item_id, uniqueness: true
  validates :reason, :substituted_at, presence: true
  validate :products_differ
  validate :matches_review_item
  validate { errors.add(:pharmacist, "يجب أن يكون صيدليًا") unless pharmacist&.pharmacist? }
  before_update { throw :abort }
  before_destroy { throw :abort }

  private

  def products_differ
    errors.add(:substitute_product, "يجب أن يختلف عن المنتج الأصلي") if original_product_id == substitute_product_id
  end

  def matches_review_item
    return unless prescription_review_item
    errors.add(:original_product, "لا يطابق سجل المراجعة") unless original_product_id == prescription_review_item.original_product_id
    errors.add(:substitute_product, "لا يطابق سجل المراجعة") unless substitute_product_id == prescription_review_item.dispensed_product_id
  end
end
