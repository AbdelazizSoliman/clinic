class Prescription < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp application/pdf].freeze
  ALLOWED_EXTENSIONS = %w[.jpg .jpeg .png .webp .pdf].freeze
  MAX_FILES = 5
  MAX_FILE_SIZE = 8.megabytes

  belongs_to :user
  belongs_to :order
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many_attached :images

  enum :status, { submitted: 0, under_review: 1, approved: 2, partially_approved: 3, rejected: 4 }, default: :submitted, validate: true
  validates :submitted_at, presence: true
  validate :validate_images

  private

  def validate_images
    errors.add(:images, "يجب إرفاق صورة أو ملف روشتة") if images.empty?
    errors.add(:images, "الحد الأقصى 5 ملفات") if images.length > MAX_FILES
    images.each do |image|
      errors.add(:images, "نوع الملف غير مدعوم") unless ALLOWED_CONTENT_TYPES.include?(image.blob.content_type)
      errors.add(:images, "امتداد الملف غير مدعوم") unless ALLOWED_EXTENSIONS.include?(File.extname(image.blob.filename.to_s).downcase)
      errors.add(:images, "حجم الملف يجب ألا يتجاوز 8 ميجابايت") if image.blob.byte_size > MAX_FILE_SIZE
      errors.add(:images, "الملف فارغ") if image.blob.byte_size.zero?
    end
  end
end
