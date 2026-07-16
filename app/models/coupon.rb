class Coupon < ApplicationRecord
  belongs_to :promotion
  has_many :redemptions, class_name: "PromotionRedemption", dependent: :restrict_with_error
  before_validation :normalize_code
  validates :code, :normalized_code, presence: true
  validates :normalized_code, uniqueness: { case_sensitive: false }
  validates :total_usage_limit, :per_customer_usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :within_promotion_schedule

  def effective?(time = Time.current)
    active? && promotion.effective?(time) && (starts_at.nil? || starts_at <= time) && (ends_at.nil? || ends_at > time)
  end

  private

  def normalize_code
    self.normalized_code = code.to_s.strip.upcase
    self.code = normalized_code
  end

  def within_promotion_schedule
    errors.add(:starts_at, "قبل بداية الحملة") if starts_at && promotion&.starts_at && starts_at < promotion.starts_at
    errors.add(:ends_at, "بعد نهاية الحملة") if ends_at && promotion&.ends_at && ends_at > promotion.ends_at
  end
end
