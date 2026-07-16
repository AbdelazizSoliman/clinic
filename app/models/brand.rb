class Brand < ApplicationRecord
  has_many :products, dependent: :restrict_with_error
  has_one_attached :logo

  validates :name, :slug, presence: true, uniqueness: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :active, inclusion: { in: [ true, false ] }
  validates :website_url, format: { with: %r{\Ahttps?://[^\s]+\z} }, allow_blank: true
  before_validation { self.name = name.to_s.squish }

  scope :active, -> { where(active: true) }

  def to_param = slug
end
