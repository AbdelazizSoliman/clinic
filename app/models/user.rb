class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable,
    :lockable, unlock_strategy: :none, maximum_attempts: 5

  has_many :carts, dependent: :restrict_with_error
  has_many :addresses, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :wishlist_products, through: :wishlist_items, source: :product
  has_many :orders, dependent: :restrict_with_error
  has_many :prescriptions, dependent: :restrict_with_error
  has_many :notifications, dependent: :destroy
  has_many :opened_follow_ups, class_name: "OrderFollowUp", foreign_key: :opened_by_id, dependent: :restrict_with_exception
  has_many :user_invitations, dependent: :destroy
  has_many :user_audit_events, dependent: :restrict_with_error
  has_many :report_exports, dependent: :restrict_with_error
  has_many :transactional_email_deliveries, dependent: :restrict_with_error

  enum :role, { customer: 0, admin: 1, pharmacist: 2, order_manager: 3, inventory_manager: 4 }, default: :customer, validate: true

  encrypts :otp_secret

  validates :first_name, :last_name, presence: true, length: { maximum: 60 }
  validates :mobile_number, presence: true, format: { with: /\A[+0-9][0-9 ]{7,14}\z/ }
  validates :active, inclusion: { in: [ true, false ] }
  before_update :bind_sensitive_changes_to_session_version

  def full_name = "#{first_name} #{last_name}"
  def privileged? = !customer?
  def two_factor_enabled? = otp_enabled_at.present? && otp_secret.present?

  def verify_totp(code)
    timestep = ROTP::TOTP.new(otp_secret, issuer: "صيدليتي").verify(code.to_s.delete(" "), drift_behind: 30, drift_ahead: 30)
    return false unless timestep && (last_otp_timestep.nil? || timestep > last_otp_timestep)
    update!(last_otp_timestep: timestep)
    true
  end

  def consume_recovery_code(code)
    digest = Digest::SHA256.hexdigest(code.to_s.delete(" -").downcase)
    return false unless recovery_code_digests.include?(digest)
    update!(recovery_code_digests: recovery_code_digests - [ digest ])
    true
  end

  def regenerate_recovery_codes!
    codes = 10.times.map { SecureRandom.hex(5).scan(/.{5}/).join("-") }
    update!(recovery_code_digests: codes.map { |code| Digest::SHA256.hexdigest(code.delete("-").downcase) })
    codes
  end
  def staff? = pharmacist? || order_manager? || admin?
  def can_review_prescriptions? = pharmacist? || admin?
  def can_operate_orders? = order_manager? || admin?
  def can_manage_delivery? = order_manager? || admin?
  alias_method :can_assign_delivery?, :can_manage_delivery?
  def can_manage_catalog? = inventory_manager? || admin?
  alias_method :can_manage_inventory?, :can_manage_catalog?
  def can_manage_promotions? = admin?
  def can_view_business_reports? = admin? || order_manager?
  def can_view_inventory_reports? = admin? || inventory_manager?
  def can_view_prescription_reports? = admin? || pharmacist?
  def can_view_fulfilment_reports? = admin? || order_manager?
  def can_export_reports? = admin? || inventory_manager? || order_manager? || pharmacist?
  def can_manage_users? = admin?
  def can_manage_application_settings? = admin?

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive_account
  end

  private

  def bind_sensitive_changes_to_session_version
    sensitive = will_save_change_to_encrypted_password? || will_save_change_to_role? ||
      will_save_change_to_active? || (will_save_change_to_otp_enabled_at? && otp_enabled_at.nil?)
    self.session_version += 1 if sensitive
  end
end
