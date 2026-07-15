class Brand < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  validates :name, :slug, presence: true, uniqueness: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  def to_param = slug
end
