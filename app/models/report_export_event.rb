class ReportExportEvent < ApplicationRecord
  TYPES = %w[sales orders products inventory promotions customers prescriptions fulfilments].freeze
  belongs_to :user
  validates :report_type, inclusion: { in: TYPES }
  validates :format, inclusion: { in: %w[csv] }
  validates :row_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate { errors.add(:range_end, "يجب أن يلي البداية") if range_start && range_end && range_end <= range_start }
  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
