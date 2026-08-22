class WebhookDelivery < ApplicationRecord
  belongs_to :organization
  belongs_to :webhook_endpoint
  validates :delivery_id, :event_name, :status, presence: true
  validates :delivery_id, uniqueness: true
end
