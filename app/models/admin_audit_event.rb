class AdminAuditEvent < ApplicationRecord
  belongs_to :actor, class_name: "User"
  belongs_to :auditable, polymorphic: true
  validates :action, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
