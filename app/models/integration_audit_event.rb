class IntegrationAuditEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :api_client, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true
  validates :action, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
