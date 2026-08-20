class ActiveIngredient < ApplicationRecord
  include Searchable

  searchable_by :name

  has_many :product_active_ingredients, dependent: :restrict_with_error
  has_many :products, through: :product_active_ingredients
  has_many :patient_allergies, dependent: :restrict_with_error
  has_many :drug_safety_rule_conditions, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }

  before_validation :normalize

  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z0-9][A-Z0-9\-]*\z/ }, length: { maximum: 40 }
  validates :name, presence: true, length: { maximum: 120 }
  validates :normalized_name, presence: true, uniqueness: true
  validates :active, inclusion: { in: [ true, false ] }

  def self.normalize_name(value) = value.to_s.unicode_normalize(:nfkc).downcase.gsub(/[[:space:]]+/, " ").strip

  private

  def normalize
    self.code = code.to_s.strip.upcase.presence
    self.name = name.to_s.squish.presence
    self.normalized_name = self.class.normalize_name(name)
  end
end
