class Organization < ApplicationRecord
  has_many :branches, dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error

  normalizes :code, with: ->(value) { value.to_s.strip.upcase }
  validates :code, :name, :timezone, :currency, :locale, presence: true
  validates :code, uniqueness: true, format: { with: /\A[A-Z0-9_-]+\z/ }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }

  def self.default_organization = unscoped.find_by(code: "DEFAULT") || unscoped.order(:id).first
end
