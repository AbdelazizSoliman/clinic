class SettingsAuditEvent < ApplicationRecord
  belongs_to :actor, class_name: "User"
  validates :action, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
