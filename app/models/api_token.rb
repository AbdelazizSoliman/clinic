class ApiToken < ApplicationRecord
  SCOPES = %w[catalog:read inventory:read orders:read orders:write purchasing:read reports:read webhooks:manage].freeze
  belongs_to :organization
  belongs_to :api_client
  validates :token_digest, :token_prefix, presence: true
  validates :token_digest, uniqueness: true
  validate { errors.add(:scopes, "تحتوي صلاحية غير مدعومة") unless scopes.all? { |scope| SCOPES.include?(scope) } }

  def self.issue!(api_client:, scopes:, expires_at: nil)
    plaintext = "cln_#{SecureRandom.urlsafe_base64(32)}"
    token = create!(organization: api_client.organization, api_client:, scopes:, expires_at:,
      token_prefix: plaintext.first(12), token_digest: digest(plaintext))
    [ token, plaintext ]
  end

  def self.authenticate(plaintext)
    return if plaintext.blank?
    token = unscoped.find_by(token_digest: digest(plaintext))
    token if token && token.revoked_at.nil? && (token.expires_at.nil? || token.expires_at.future?) && token.api_client.active?
  end

  def self.digest(value) = Digest::SHA256.hexdigest(value.to_s)
  def allows?(scope) = scopes.include?(scope)
  def revoke! = update!(revoked_at: Time.current)
end
