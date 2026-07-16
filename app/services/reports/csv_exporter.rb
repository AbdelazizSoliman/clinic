require "csv"

module Reports
  class CsvExporter
    BOM = "\uFEFF"
    MAX_ROWS = 10_000
    DANGEROUS_PREFIX = /\A[=+\-@\t\r]/
    Result = Data.define(:content, :row_count)

    def self.call(headers:, rows:)
      count = 0
      content = CSV.generate(BOM, force_quotes: true) do |csv|
        csv << headers.map { |cell| sanitize(cell) }
        rows.each do |row|
          raise RangeError, "export_too_large" if count >= MAX_ROWS
          csv << row.map { |cell| sanitize(cell) }
          count += 1
        end
      end
      Result.new(content:, row_count: count)
    end

    def self.sanitize(value)
      text = value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) ? value.in_time_zone("Africa/Cairo").strftime("%Y-%m-%d %H:%M") : value.to_s
      text.match?(DANGEROUS_PREFIX) ? "'#{text}" : text
    end
  end
end
