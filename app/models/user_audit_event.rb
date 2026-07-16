class UserAuditEvent < ApplicationRecord
  ACTIONS = %w[invited invitation_resent invitation_revoked invitation_accepted activated deactivated role_changed profile_updated_by_admin account_unlocked password_reset_requested_by_admin bootstrap_admin].freeze

  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  validates :action, inclusion: { in: ACTIONS }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
