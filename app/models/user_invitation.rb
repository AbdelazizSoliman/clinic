class UserInvitation < ApplicationRecord
  EXPIRY = 72.hours

  belongs_to :user
  belongs_to :invited_by, class_name: "User"

  validates :token_digest, :sent_at, :expires_at, presence: true
  validates :token_digest, uniqueness: true
  validates :attempts_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(accepted_at: nil, revoked_at: nil).where("expires_at > ?", Time.current) }

  def accepted? = accepted_at.present?
  def revoked? = revoked_at.present?
  def expired? = expires_at <= Time.current
  def usable? = !accepted? && !revoked? && !expired?

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token)
end
