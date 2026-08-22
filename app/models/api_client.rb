class ApiClient < ApplicationRecord
  belongs_to :organization
  has_many :api_tokens, dependent: :restrict_with_error
  validates :name, presence: true
  validates :rate_limit_per_minute, numericality: { only_integer: true, in: 1..10_000 }
end
