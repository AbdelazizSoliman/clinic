class LoyaltyRule < ApplicationRecord
  enum :rule_type, { earning: 0, redemption: 1 }, validate: true
  validates :code, :name, presence: true
  validates :code, uniqueness: true
  validates :minimum_eligible_spend_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :expiration_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :configuration_is_valid
  scope :effective_at, ->(time = Time.current) { where(active: true).where("effective_from IS NULL OR effective_from <= ?", time).where("effective_to IS NULL OR effective_to > ?", time) }

  def self.current(type, at: Time.current) = effective_at(at).where(rule_type: type).order(effective_from: :desc, id: :desc).first

  private

  def configuration_is_valid
    if earning? && !(points_awarded.to_i.positive? && spend_threshold_cents.to_i.positive?)
      errors.add(:base, "قاعدة الكسب تحتاج نقاطاً وحد إنفاق موجبين")
    elsif redemption? && !(redemption_points.to_i.positive? && redemption_value_cents.to_i.positive?)
      errors.add(:base, "قاعدة الاستبدال تحتاج نقاطاً وقيمة موجبتين")
    end
    errors.add(:effective_to, "يجب أن يلي البداية") if effective_from && effective_to && effective_to <= effective_from
  end
end
