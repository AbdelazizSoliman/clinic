class PharmacySetting < ApplicationRecord
  has_one_attached :logo do |attachable|
    attachable.variant :header, resize_to_fill: [ 96, 96 ], preprocessed: true
  end

  validates :singleton_key, inclusion: { in: [ 1 ] }, uniqueness: true
  validates :pharmacy_name, :default_currency, :default_locale, :time_zone, :order_number_prefix, presence: true
  validates :default_currency, inclusion: { in: %w[EGP] }
  validates :default_locale, inclusion: { in: %w[ar] }
  validates :time_zone, inclusion: { in: %w[Africa/Cairo] }
  validates :default_low_stock_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :default_maximum_order_quantity, numericality: { only_integer: true, in: 1..100 }
  validates :default_reservation_minutes, numericality: { only_integer: true, in: 5..1440 }
  validates :pending_prescription_reservation_hours, numericality: { only_integer: true, in: 1..168 }
  validates :support_email, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :acceptable_logo

  def self.current
    Rails.cache.fetch("pharmacy-setting/current", expires_in: 5.minutes) { first || new }
  end

  def self.invalidate_cache = Rails.cache.delete("pharmacy-setting/current")

  private

  def acceptable_logo
    return unless logo.attached?
    errors.add(:logo, "يجب أن تكون PNG أو JPEG أو WebP") unless logo.blob.content_type.in?(%w[image/png image/jpeg image/webp])
    errors.add(:logo, "يجب ألا يتجاوز الشعار 2 ميجابايت") if logo.blob.byte_size > 2.megabytes
  end
end
