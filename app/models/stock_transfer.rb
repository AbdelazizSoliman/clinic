class StockTransfer < ApplicationRecord
  belongs_to :source_branch, class_name: "Branch"
  belongs_to :destination_branch, class_name: "Branch"
  belongs_to :created_by, class_name: "User"
  belongs_to :submitted_by, class_name: "User", optional: true
  belongs_to :dispatched_by, class_name: "User", optional: true
  belongs_to :received_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_many :items, class_name: "StockTransferItem", dependent: :restrict_with_error

  enum :status, { draft: 0, submitted: 1, dispatched: 2, received: 3, closed: 4, cancelled: 5 }, validate: true
  validates :number, presence: true, uniqueness: true
  validate { errors.add(:destination_branch, "يجب أن يختلف الفرعان") if source_branch_id == destination_branch_id }
  validates :cancellation_reason, presence: true, if: :cancelled?
end
