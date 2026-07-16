class Promotion < ApplicationRecord
  TYPES = %w[product category brand cart delivery].freeze
  DISCOUNT_TYPES = %w[percentage fixed_amount fixed_price free_delivery].freeze
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :delivery_zone, optional: true
  has_many :coupons, dependent: :restrict_with_error
  has_many :promotion_products, dependent: :destroy
  has_many :products, through: :promotion_products
  has_many :promotion_categories, dependent: :destroy
  has_many :categories, through: :promotion_categories
  has_many :promotion_brands, dependent: :destroy
  has_many :brands, through: :promotion_brands
  has_many :promotion_exclusions, dependent: :destroy
  has_many :excluded_products, through: :promotion_exclusions, source: :product
  has_many :redemptions, class_name: "PromotionRedemption", dependent: :restrict_with_error
  has_many :promotion_audit_events, dependent: :restrict_with_error

  validates :name, :internal_name, presence: true
  validates :promotion_type, inclusion: { in: TYPES }
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, :minimum_subtotal_cents, :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :maximum_discount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_usage_limit, :per_customer_usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :valid_schedule
  validate :compatible_discount

  scope :effective_at, ->(time = Time.current) { where(active: true).where("starts_at <= ? AND ends_at > ?", time, time) }
  scope :automatic, -> { where(automatic: true) }

  def effective?(time = Time.current) = active? && starts_at <= time && ends_at > time
  def lifecycle_status(time = Time.current)
    return "paused" unless active?
    return "scheduled" if starts_at > time
    return "expired" if ends_at <= time
    "active"
  end

  private

  def valid_schedule
    errors.add(:ends_at, "يجب أن يكون بعد وقت البداية") if starts_at && ends_at && ends_at <= starts_at
  end

  def compatible_discount
    errors.add(:discount_value, "النسبة يجب أن تكون بين 1 و100") if discount_type == "percentage" && !discount_value.between?(1, 100)
    errors.add(:discount_type, "السعر الثابت متاح لعروض المنتجات فقط") if discount_type == "fixed_price" && promotion_type != "product"
    errors.add(:discount_type, "التوصيل المجاني متاح لعروض التوصيل فقط") if discount_type == "free_delivery" && promotion_type != "delivery"
  end
end
