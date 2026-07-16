class ReportExport < ApplicationRecord
  TYPES = ReportExportEvent::TYPES
  RETENTION = ENV.fetch("REPORT_EXPORT_RETENTION_DAYS", 7).to_i.days
  MAX_ACTIVE_PER_USER = ENV.fetch("REPORT_EXPORT_MAX_ACTIVE", 3).to_i

  belongs_to :user
  has_one_attached :file

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3, expired: 4 }, validate: true
  validates :report_type, inclusion: { in: TYPES }
  validates :requested_at, :deduplication_key, presence: true
  validates :row_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  scope :active, -> { where(status: %i[pending processing]) }
  scope :recent_first, -> { order(created_at: :desc) }

  def downloadable_by?(actor)
    completed? && file.attached? && expires_at&.future? && (actor == user || actor&.admin?)
  end
end
