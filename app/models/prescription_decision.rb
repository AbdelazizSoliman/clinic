class PrescriptionDecision < ApplicationRecord
  STATUSES = %w[pending under_review approved substituted rejected].freeze

  belongs_to :prescription_review_item
  belongs_to :actor, class_name: "User"

  validates :from_status, :to_status, inclusion: { in: STATUSES }
  validates :reason, presence: true, if: -> { to_status.in?(%w[approved substituted rejected]) }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
