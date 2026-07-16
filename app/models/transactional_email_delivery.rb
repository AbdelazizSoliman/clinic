class TransactionalEmailDelivery < ApplicationRecord
  belongs_to :user
  belongs_to :notification, optional: true

  enum :status, { queued: 0, processing: 1, delivered: 2, failed: 3, cancelled: 4 }, validate: true
  validates :mailer, :action, :deduplication_key, :queued_at, presence: true
  validates :deduplication_key, uniqueness: true
  validates :attempts_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  scope :actionable, -> { where(status: %i[queued processing failed]) }
end
