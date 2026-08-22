class WebhookEndpoint < ApplicationRecord
  EVENTS = %w[order.created order.updated order.completed inventory.changed return.completed purchase_order.received].freeze
  belongs_to :organization
  has_many :deliveries, class_name: "WebhookDelivery", dependent: :restrict_with_error
  encrypts :encrypted_secret
  validates :url, :encrypted_secret, :secret_digest, presence: true
  validate :safe_url
  validate { errors.add(:subscribed_events, "تحتوي حدثًا غير مدعوم") unless subscribed_events.all? { |event| EVENTS.include?(event) } }

  def self.build_with_secret(attributes)
    secret = SecureRandom.urlsafe_base64(32)
    [ new(attributes.merge(encrypted_secret: secret, secret_digest: Digest::SHA256.hexdigest(secret))), secret ]
  end

  private

  def safe_url
    Webhooks::UrlPolicy.validate!(url)
  rescue Webhooks::UrlPolicy::UnsafeUrl => error
    errors.add(:url, error.message)
  end
end
