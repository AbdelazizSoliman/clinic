class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error
  has_one_attached :image

  validates :name, :slug, presence: true, uniqueness: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  before_validation { self.name = name.to_s.squish }

  scope :active, -> { where(active: true) }

  def to_param = slug
end
