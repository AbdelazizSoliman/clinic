class Product < ApplicationRecord
  belongs_to :category
  belongs_to :brand
  has_many :wishlist_items, dependent: :destroy
  has_many :inventory_reservations, dependent: :restrict_with_error
  has_many :order_items, dependent: :nullify

  scope :active, -> { where(active: true) }
  scope :featured, -> { active.where(featured: true) }
  scope :discounted, -> { active.where("compare_at_price > price") }
  scope :available, -> { where("stock_quantity > 0") }

  validates :name, :slug, :price, :stock_quantity, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :compare_at_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :compare_at_price_exceeds_price

  def to_param = slug

  def discounted?
    compare_at_price.present? && compare_at_price > price
  end

  def discount_percentage
    return 0 unless discounted?

    ((compare_at_price - price) / compare_at_price * 100).round
  end

  def active_reserved_quantity
    inventory_reservations.active.sum(:quantity)
  end

  def available_to_sell_quantity
    [ stock_quantity - active_reserved_quantity, 0 ].max
  end

  def available? = available_to_sell_quantity.positive?

  private

  def compare_at_price_exceeds_price
    return if compare_at_price.blank? || price.blank? || compare_at_price > price

    errors.add(:compare_at_price, "يجب أن يكون أكبر من السعر الحالي")
  end
end
