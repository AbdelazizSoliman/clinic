class BranchMembership < ApplicationRecord
  belongs_to :branch
  belongs_to :user
  validates :branch_id, uniqueness: { scope: :user_id }
  validates :active, inclusion: { in: [ true, false ] }
end
