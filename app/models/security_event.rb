class SecurityEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :actor, class_name: "User", optional: true

  validates :event_type, presence: true
  validate :immutable, on: :update

  def readonly? = persisted?

  def self.record(event_type, user: nil, actor: nil, request: nil, metadata: {})
    create!(event_type:, user:, actor:, metadata: metadata.slice(:role, :reason, :action),
      ip_digest: digest_ip(request&.remote_ip),
      user_agent_summary: request&.user_agent.to_s.first(200).presence)
  end

  def self.digest_ip(ip)
    return if ip.blank?
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, ip)
  end

  private

  def immutable = errors.add(:base, "Security events are append-only")
end
