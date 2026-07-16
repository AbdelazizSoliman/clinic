class PromotionAuditEvent < ApplicationRecord
  belongs_to :promotion
  belongs_to :actor, class_name: "User"
  validates :action, presence: true
  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
