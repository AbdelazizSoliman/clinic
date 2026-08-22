class ApiIdempotencyRecord < ApplicationRecord
  belongs_to :organization
  belongs_to :api_client
  validates :action, :key, :request_digest, presence: true
  validates :key, uniqueness: { scope: %i[organization_id api_client_id action] }
end
