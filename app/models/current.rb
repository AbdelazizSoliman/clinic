class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization, :branch, :branch_scope
end
