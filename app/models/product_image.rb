class ProductImage < ApplicationRecord
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_SIZE = 8.megabytes

  belongs_to :product, inverse_of: :images
  has_one_attached :file
  validates :alt_text, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :product_id }
  validates :primary, inclusion: { in: [ true, false ] }, uniqueness: { scope: :product_id }, if: :primary?
  validate :valid_file

  private

  def valid_file
    errors.add(:file, "مطلوب") unless file.attached?
    return unless file.attached?
    errors.add(:file, "نوع الصورة غير مدعوم") unless ALLOWED_TYPES.include?(file.blob.content_type)
    errors.add(:file, "حجم الصورة يتجاوز 8 ميجابايت") if file.blob.byte_size > MAX_SIZE
    errors.add(:file, "الحد الأقصى 8 صور") if product && product.images.where.not(id: id).count >= 8
  end
end
