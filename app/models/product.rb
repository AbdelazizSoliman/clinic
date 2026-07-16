class Product < ApplicationRecord
  belongs_to :category
  belongs_to :brand
  has_many :wishlist_items, dependent: :destroy
  has_many :inventory_reservations, dependent: :restrict_with_error
  has_many :order_items, dependent: :nullify
  has_many :images, -> { order(primary: :desc, position: :asc) }, class_name: "ProductImage", dependent: :destroy, inverse_of: :product
  has_many :price_changes, class_name: "ProductPriceChange", dependent: :restrict_with_error
  has_many :inventory_movements, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }
  scope :featured, -> { active.where(featured: true) }
  scope :discounted, -> { active.where("compare_at_price > price") }
  scope :available, -> { where("stock_quantity > 0") }
  scope :publicly_available, -> { active.joins(:category, :brand).merge(Category.active).merge(Brand.active) }
  scope :discontinued, -> { where.not(discontinued_at: nil) }

  validates :name, :slug, :price, :stock_quantity, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :compare_at_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cost_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :low_stock_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :maximum_order_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :sku, :barcode, uniqueness: true, allow_blank: true
  validates :active, :featured, :requires_prescription, :cold_chain_required, inclusion: { in: [ true, false ] }
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
    return inventory_reservations.select(&:active?).sum(&:quantity) if inventory_reservations.loaded?

    inventory_reservations.active.sum(:quantity)
  end

  def available_to_sell_quantity
    [ stock_quantity - active_reserved_quantity, 0 ].max
  end

  def available? = available_to_sell_quantity.positive?
  def low_stock? = available? && available_to_sell_quantity <= low_stock_threshold
  def out_of_stock? = available_to_sell_quantity <= 0
  def primary_image = images.find(&:primary?) || images.first
  def published? = active? && published_at.present? && discontinued_at.nil?

  def deletable?
    order_items.none? && inventory_reservations.none? && cart_items.none?
  end

  has_many :cart_items, dependent: :restrict_with_error

  private

  def compare_at_price_exceeds_price
    return if compare_at_price.blank? || price.blank? || compare_at_price > price

    errors.add(:compare_at_price, "يجب أن يكون أكبر من السعر الحالي")
  end
end
